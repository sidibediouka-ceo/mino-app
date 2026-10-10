import Foundation
import MinoKit

/// The whole family as the domain sees it, built once per render from SwiftData objects.
struct FamilySnapshot {
    let children: [Child]
    let profiles: [ChildProfile]
    let items: [WardrobeItem]
    private let garmentsByID: [UUID: Garment]

    init(children: [Child], garments: [Garment]) {
        self.children = children
        self.profiles = children.map(\.profile)
        self.items = garments.map(\.item)
        self.garmentsByID = Dictionary(garments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func garment(_ id: UUID) -> Garment? { garmentsByID[id] }

    func profile(_ id: UUID) -> ChildProfile? { profiles.first { $0.id == id } }

    /// Family garments `child` could take over on `date`, best fitting first.
    func availableGarments(for child: Child, on date: Date) -> [Garment] {
        guard let profile = profile(child.id) else { return [] }
        return FamilyStock.available(for: profile, family: profiles, items: items, on: date).compactMap { garment($0.id) }
    }

    /// The child's next passage and what it asks for.
    func passagePlan(for child: Child, covered: [CoveredNeed], calendar: Calendar) -> PassagePlan? {
        guard let profile = profile(child.id) else { return nil }
        let passage = Passage.next(for: profile, on: .now, calendar: calendar)
        let coveredIDs = Set(covered.filter(\.isCurrent).map(\.needID))
        return PassagePlan(passage: passage, child: profile, family: profiles, items: items, covered: coveredIDs)
    }
}
