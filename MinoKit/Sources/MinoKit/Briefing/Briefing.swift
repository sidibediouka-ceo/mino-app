import Foundation

/// One thing worth doing about the wardrobe. Every item maps to a single concrete action.
/// Size outlook and needs are shown where they belong (the Growth screen); the briefing only
/// holds what asks for a gesture.
public enum BriefingItem: Identifiable, Equatable, Sendable {
    /// Garments that are probably too small: a one-minute sorting session.
    case sort(childID: UUID, itemIDs: [UUID])
    /// The family boxes already hold what the child will need.
    case retrieve(Need)
    /// A fresh measurement would sharpen every projection.
    case measure(childID: UUID)

    public var id: String {
        switch self {
        case .sort(let child, _): return "sort-\(child)"
        case .retrieve(let need): return "retrieve-\(need.id)"
        case .measure(let child): return "measure-\(child)"
        }
    }

    public var childID: UUID {
        switch self {
        case .sort(let child, _), .measure(let child): return child
        case .retrieve(let need): return need.childID
        }
    }

    fileprivate var priority: Int {
        switch self {
        case .sort: return 0
        case .retrieve: return 1
        case .measure: return 2
        }
    }
}

/// Fewer actions, better ones: what deserves a gesture, most useful first.
public enum Briefing {
    public static func compose(family: [ChildProfile], items: [WardrobeItem], needs: [Need], on date: Date) -> [BriefingItem] {
        var suggestions: [(item: BriefingItem, childRank: Int)] = []
        for (rank, child) in family.enumerated() {
            let own = items.filter { $0.ownerID == child.id && $0.state == .active }
            let outgrown = own.filter { child.fit(of: $0, on: date) == .tooSmall }.map(\.id)
            if !outgrown.isEmpty {
                suggestions.append((.sort(childID: child.id, itemIDs: outgrown), rank))
            }
            for need in needs where need.childID == child.id && !need.familyStock.isEmpty {
                suggestions.append((.retrieve(need), rank))
            }
            if child.lastMeasuredHeightDate.map({ date.timeIntervalSince($0) > 120 * 86_400 }) ?? true {
                suggestions.append((.measure(childID: child.id), rank))
            }
        }
        return suggestions
            .sorted { ($0.item.priority, $0.childRank) < ($1.item.priority, $1.childRank) }
            .map(\.item)
    }
}
