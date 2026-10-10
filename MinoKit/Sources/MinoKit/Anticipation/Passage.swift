import Foundation

/// The two moments that reshape a child's wardrobe: moving into the next size, and the big
/// seasonal switch between light and warm clothes (the Japanese 衣替え, koromogae).
public enum PassageKind: Equatable, Sendable {
    /// The child moves into this clothing size.
    case size(Int)
    /// Summer clothes come out (1 June) or warm clothes come out (1 September).
    case season(Season)
}

public struct Passage: Equatable, Sendable {
    public let kind: PassageKind
    public let when: DateEstimate
    /// The season the wardrobe must be ready for.
    public let season: Season

    public var date: Date { when.expected }

    /// A passage is prepared during the four weeks before it, and stays open two weeks after.
    static let preparationDays = 28
    static let graceDays = 14

    public func isUnderway(on date: Date) -> Bool {
        date >= self.date.addingTimeInterval(-Double(Self.preparationDays) * 86_400)
    }

    /// The child's next passage: whichever comes first between the next size and the next
    /// seasonal switch.
    public static func next(for child: ChildProfile, on date: Date, calendar: Calendar) -> Passage {
        let reference = date.addingTimeInterval(-Double(graceDays) * 86_400)
        let switchDates = [Season.summer, .autumn].map { ($0, $0.nextStart(after: reference, calendar: calendar)) }
        let (season, start) = switchDates.min { $0.1 < $1.1 } ?? (.summer, date)
        let seasonal = Passage(
            kind: .season(season), when: DateEstimate(expected: start, earliest: start, latest: start), season: season
        )
        guard let milestone = child.nextSize(.clothing, after: date), milestone.when.expected < start else {
            return seasonal
        }
        return Passage(kind: .size(milestone.size), when: milestone.when, season: Season.of(milestone.when.expected, calendar: calendar))
    }
}

/// Everything a passage asks for, in the order a parent handles it: sort what becomes small,
/// take over what the family already has, and list what is left to find.
public struct PassagePlan: Equatable, Sendable {
    public let passage: Passage
    /// The child's garments that will be too small by then.
    public let outgrown: [UUID]
    /// Family garments (boxes, outgrown by a sibling) that will fit by then.
    public let fromFamily: [UUID]
    /// What the season's wardrobe still lacks, minus what the parent said they already have.
    public let needs: [Need]
    /// False while the wardrobe is too sparse to judge: Mino then never claims it is ready.
    public let knowsWardrobe: Bool

    /// - Parameter covered: identifiers of needs the parent answered "J'en ai assez" to.
    public init(passage: Passage, child: ChildProfile, family: [ChildProfile], items: [WardrobeItem], covered: Set<String>) {
        let date = passage.date
        let own = items.filter { $0.ownerID == child.id && $0.state == .active }
        self.passage = passage
        self.outgrown = own.filter { child.fit(of: $0, on: date) == .tooSmall }.map(\.id)
        self.fromFamily = FamilyStock.available(for: child, family: family, items: items, on: date).map(\.id)
        self.needs = NeedsForecaster.needs(for: child, family: family, items: items, season: passage.season, on: date)
            .filter { !covered.contains($0.id) }
        self.knowsWardrobe = own.count >= NeedsForecaster.minimumItemsForAdvice
    }

    /// Needs the family boxes cannot fill.
    public var toFind: [Need] { needs.filter { $0.stillMissing > 0 } }

    public var isReady: Bool { knowsWardrobe && outgrown.isEmpty && toFind.isEmpty }
}
