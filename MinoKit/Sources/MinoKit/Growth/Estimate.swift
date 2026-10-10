import Foundation

/// A projected value with an honest uncertainty band (about one standard deviation).
public struct Estimate: Equatable, Sendable {
    public let expected: Double
    public let low: Double
    public let high: Double

    public init(expected: Double, low: Double, high: Double) {
        self.expected = expected
        self.low = low
        self.high = high
    }
}

/// A projected date together with the window in which it most likely happens.
public struct DateEstimate: Equatable, Sendable {
    public let expected: Date
    public let earliest: Date
    public let latest: Date

    public init(expected: Date, earliest: Date, latest: Date) {
        self.expected = expected
        self.earliest = earliest
        self.latest = latest
    }
}

/// Finds when a growing quantity is expected to cross a threshold, scanning week by week.
func firstDate(
    reaching target: Double,
    from start: Date,
    horizonDays: Int,
    estimate: (Date) -> Estimate
) -> DateEstimate? {
    var expected: Date?
    var earliest: Date?
    for day in stride(from: 0, through: horizonDays, by: 7) {
        let date = start.addingTimeInterval(TimeInterval(day) * 86_400)
        let value = estimate(date)
        if earliest == nil, value.high >= target { earliest = date }
        if expected == nil, value.expected >= target { expected = date }
        if value.low >= target, let expected, let earliest {
            return DateEstimate(expected: expected, earliest: earliest, latest: date)
        }
    }
    guard let expected else { return nil }
    let horizonEnd = start.addingTimeInterval(TimeInterval(horizonDays) * 86_400)
    return DateEstimate(expected: expected, earliest: earliest ?? expected, latest: horizonEnd)
}
