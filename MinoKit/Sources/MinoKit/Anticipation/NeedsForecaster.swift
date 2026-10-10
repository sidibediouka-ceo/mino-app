import Foundation

/// Something a child will lack, when, in which size, and what the family already has to fill it.
public struct Need: Identifiable, Equatable, Sendable {
    public let childID: UUID
    public let group: NeedGroup
    public let season: Season
    public let neededBy: Date
    /// Size to look for: it fits at `neededBy` and leaves room to grow.
    public let size: Int
    public let missing: Int
    /// Stored or outgrown family garments that will fit, best first (at most `missing`).
    public let familyStock: [UUID]

    public var id: String { "\(childID.uuidString)-\(group.rawValue)-\(season.rawValue)" }

    /// What is left to find once the family boxes have been used.
    public var stillMissing: Int { missing - familyStock.count }
}

/// "The wardrobe that anticipates": compares a simple seasonal capsule with what will still
/// fit at the moment it matters, then looks in the family boxes before anything else.
public struct NeedsForecaster {
    /// Below this many garments, advice would be noise: the wardrobe is simply not entered yet.
    public static let minimumItemsForAdvice = 8

    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func needs(for child: ChildProfile, family: [ChildProfile], items: [WardrobeItem], on date: Date) -> [Need] {
        let own = items.filter { $0.ownerID == child.id && $0.state == .active }
        guard own.count >= Self.minimumItemsForAdvice else { return [] }

        let soon = date.addingTimeInterval(42 * 86_400)
        var checkpoints = [(season: Season.of(date, calendar: calendar), date: soon)]
        let nextSeason = Season.of(date, calendar: calendar).next
        let nextStart = nextSeason.nextStart(after: date, calendar: calendar)
        if nextStart.timeIntervalSince(date) <= 56 * 86_400 {
            checkpoints.append((nextSeason, nextStart))
        }

        var needs: [Need] = []
        for checkpoint in checkpoints {
            for group in NeedGroup.allCases {
                let target = group.target(in: checkpoint.season)
                guard target > 0 else { continue }
                let fitting = own.filter { group.categories.contains($0.category) && child.fit(of: $0, on: checkpoint.date).isWearable }
                let missing = target - fitting.count
                guard missing > 0 else { continue }
                let stock = FamilyStock.available(for: child, family: family, items: items, on: checkpoint.date)
                    .filter { group.categories.contains($0.category) && child.fit(of: $0, on: checkpoint.date) == .fits }
                    .map(\.id)
                needs.append(Need(
                    childID: child.id, group: group, season: checkpoint.season, neededBy: checkpoint.date,
                    size: recommendedSize(for: child, kind: group.sizeKind, at: checkpoint.date),
                    missing: missing, familyStock: Array(stock.prefix(missing))
                ))
            }
        }
        return needs.sorted { ($0.neededBy, -$0.missing) < ($1.neededBy, -$1.missing) }
    }

    private func recommendedSize(for child: ChildProfile, kind: SizeKind, at date: Date) -> Int {
        switch kind {
        case .clothing:
            let roomToGrow = date.addingTimeInterval(90 * 86_400)
            return SizeChart.wornClothingSize(forHeight: child.height(at: roomToGrow).expected)
        case .shoes:
            let roomToGrow = date.addingTimeInterval(60 * 86_400)
            return SizeChart.wornShoeSize(forEstimate: child.shoeSize(at: roomToGrow).expected)
        }
    }
}
