import Foundation

/// A dated observation of a child's stature and/or shoe size.
public struct GrowthRecord: Equatable, Sendable {
    public let date: Date
    public let heightCM: Double?
    public let shoeSize: Double?
    /// True when the height was inferred from the clothing size the parent reported.
    public let isApproximate: Bool

    public init(date: Date, heightCM: Double?, shoeSize: Double?, isApproximate: Bool = false) {
        self.date = date
        self.heightCM = heightCM
        self.shoeSize = shoeSize
        self.isApproximate = isApproximate
    }
}

/// Everything Mino needs to know about a child to reason about their wardrobe, and no more:
/// a first name (or nickname), an age and sizes. No date of birth, no sex.
public struct ChildProfile: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    /// Derived from the age the parent gave ("4 ans"); only ever approximate.
    public let estimatedBirth: Date
    public let records: [GrowthRecord]

    public init(id: UUID, name: String, estimatedBirth: Date, records: [GrowthRecord]) {
        self.id = id
        self.name = name
        self.estimatedBirth = estimatedBirth
        self.records = records.sorted { $0.date < $1.date }
    }

    /// The estimated birth of a child who was `ageInMonths` old on `date`.
    public static func estimatedBirth(ageInMonths: Int, on date: Date) -> Date {
        date.addingTimeInterval(-Double(ageInMonths) * secondsPerMonth)
    }

    static let secondsPerMonth = 30.436_875 * 86_400

    public func ageInMonths(at date: Date) -> Double {
        max(0, date.timeIntervalSince(estimatedBirth) / Self.secondsPerMonth)
    }

    /// The date of the last real (not inferred) height measurement.
    public var lastMeasuredHeightDate: Date? {
        records.last { $0.heightCM != nil && !$0.isApproximate }?.date
    }

    // MARK: Stature

    /// Projects stature by keeping the child on their own growth channel (constant z-score)
    /// relative to the WHO reference. Uncertainty widens with distance from the last record.
    public func height(at date: Date) -> Estimate {
        let age = ageInMonths(at: date)
        let median = GrowthReference.medianStature(ageMonths: age)
        let deviation = GrowthReference.statureStandardDeviation(ageMonths: age)
        guard let anchor = records.last(where: { $0.heightCM != nil }), let anchorHeight = anchor.heightCM else {
            return Estimate(expected: median, low: median - deviation, high: median + deviation)
        }
        let anchorAge = ageInMonths(at: anchor.date)
        let anchorMedian = GrowthReference.medianStature(ageMonths: anchorAge)
        let anchorDeviation = GrowthReference.statureStandardDeviation(ageMonths: anchorAge)
        let zScore = (anchorHeight - anchorMedian) / anchorDeviation
        var expected = median + zScore * deviation
        if date >= anchor.date { expected = max(expected, anchorHeight) }
        let years = abs(date.timeIntervalSince(anchor.date)) / (Self.secondsPerMonth * 12)
        let base = anchor.isApproximate ? 2.5 : 0.5
        let spread = min(deviation, base + deviation * 0.3 * years)
        return Estimate(expected: expected, low: expected - spread, high: expected + spread)
    }

    public func dateReaching(heightCM target: Double, from start: Date) -> DateEstimate? {
        firstDate(reaching: target, from: start, horizonDays: 3 * 365) { height(at: $0) }
    }

    // MARK: Shoes

    /// Projects shoe size by keeping the offset observed at the last record against the typical curve.
    public func shoeSize(at date: Date) -> Estimate {
        let typical = GrowthReference.typicalShoeSize(ageMonths: ageInMonths(at: date))
        guard let anchor = records.last(where: { $0.shoeSize != nil }), let anchorSize = anchor.shoeSize else {
            return Estimate(expected: typical, low: typical - 1.5, high: typical + 1.5)
        }
        let offset = anchorSize - GrowthReference.typicalShoeSize(ageMonths: ageInMonths(at: anchor.date))
        var expected = typical + offset
        if date >= anchor.date { expected = max(expected, anchorSize) }
        let years = abs(date.timeIntervalSince(anchor.date)) / (Self.secondsPerMonth * 12)
        let spread = min(2, 0.3 + 0.6 * years)
        return Estimate(expected: expected, low: expected - spread, high: expected + spread)
    }

    public func dateReaching(shoeSize target: Double, from start: Date) -> DateEstimate? {
        firstDate(reaching: target, from: start, horizonDays: 3 * 365) { shoeSize(at: $0) }
    }
}
