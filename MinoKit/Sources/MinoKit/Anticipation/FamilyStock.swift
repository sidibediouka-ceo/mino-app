import Foundation

/// The living family wardrobe: what a child could take over without buying anything.
public enum FamilyStock {
    /// Garments in the family boxes, or outgrown by a sibling on `date`, that fit `child` then
    /// (properly fitting ones first, then the slightly big ones).
    public static func available(for child: ChildProfile, family: [ChildProfile], items: [WardrobeItem], on date: Date) -> [WardrobeItem] {
        let siblings = Dictionary(uniqueKeysWithValues: family.filter { $0.id != child.id }.map { ($0.id, $0) })
        let candidates = items.filter { item in
            guard child.fit(of: item, on: date).isWearable else { return false }
            switch item.state {
            case .stored:
                return true
            case .active:
                guard let ownerID = item.ownerID, let owner = siblings[ownerID] else { return false }
                return owner.fit(of: item, on: date) == .tooSmall
            default:
                return false
            }
        }
        return candidates.filter { child.fit(of: $0, on: date) == .fits } + candidates.filter { child.fit(of: $0, on: date) == .roomy }
    }
}
