import Foundation

/// Something a child will lack, when, in which size, and what the family already has to fill it.
public struct Need: Identifiable, Equatable, Sendable {
    public let childID: UUID
    public let group: NeedGroup
    public let season: Season
    /// Size to look for: it fits when needed and leaves room to grow.
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
public enum NeedsForecaster {
    /// Below this many garments, advice would be noise: the wardrobe is simply not entered yet.
    public static let minimumItemsForAdvice = 8

    /// What `child` will lack for `season`, judged on what fits them on `date`.
    public static func needs(for child: ChildProfile, family: [ChildProfile], items: [WardrobeItem], season: Season, on date: Date) -> [Need] {
        let own = items.filter { $0.ownerID == child.id && $0.state == .active }
        guard own.count >= minimumItemsForAdvice else { return [] }
        let familyStock = FamilyStock.available(for: child, family: family, items: items, on: date)
            .filter { child.fit(of: $0, on: date) == .fits }

        return NeedGroup.allCases.compactMap { group -> Need? in
            let target = group.target(in: season)
            let fitting = own.filter { group.categories.contains($0.category) && child.fit(of: $0, on: date).isWearable }
            let missing = target - fitting.count
            guard missing > 0 else { return nil }
            let stock = familyStock.filter { group.categories.contains($0.category) }.map(\.id)
            return Need(
                childID: child.id, group: group, season: season,
                size: recommendedSize(for: child, kind: group.sizeKind, at: date),
                missing: missing, familyStock: Array(stock.prefix(missing))
            )
        }
        .sorted { $0.missing > $1.missing }
    }

    private static func recommendedSize(for child: ChildProfile, kind: SizeKind, at date: Date) -> Int {
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
