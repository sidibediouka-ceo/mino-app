import Foundation

/// "Passes into 110 around mid-February (between January and March)."
public struct SizeMilestone: Equatable, Sendable {
    public let size: Int
    public let when: DateEstimate
}

extension ChildProfile {
    /// The size the child wears on `date`.
    public func currentSize(_ kind: SizeKind, on date: Date) -> Int {
        switch kind {
        case .clothing: return SizeChart.wornClothingSize(forHeight: height(at: date).expected)
        case .shoes: return SizeChart.wornShoeSize(forEstimate: shoeSize(at: date).expected)
        }
    }

    /// The next size the child will move into, and when.
    public func nextSize(_ kind: SizeKind, after date: Date) -> SizeMilestone? {
        let current = currentSize(kind, on: date)
        switch kind {
        case .clothing:
            guard let next = SizeChart.nextClothingSize(after: current),
                  let when = dateReaching(heightCM: Double(current) + 2.01, from: date) else { return nil }
            return SizeMilestone(size: next, when: when)
        case .shoes:
            guard let when = dateReaching(shoeSize: Double(current) + 0.01, from: date) else { return nil }
            return SizeMilestone(size: current + 1, when: when)
        }
    }
}
