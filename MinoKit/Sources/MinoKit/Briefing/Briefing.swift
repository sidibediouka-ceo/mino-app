import Foundation

/// One useful thing to do now. Every item maps to a single concrete action in the app.
public enum BriefingItem: Identifiable, Equatable, Sendable {
    /// The wardrobe is too empty for good advice: add a few photos.
    case addGarments(childID: UUID)
    /// Garments that are probably too small: a one-minute sorting session.
    case sort(childID: UUID, itemIDs: [UUID])
    /// The family boxes already hold what the child will need.
    case retrieve(Need)
    /// Something to find before a date, after the boxes have been checked.
    case prepare(Need)
    /// The child is about to move into the next size.
    case sizeUp(childID: UUID, milestone: SizeMilestone)
    /// A fresh measurement would sharpen every projection.
    case measure(childID: UUID)

    public var id: String {
        switch self {
        case .addGarments(let child): return "add-\(child)"
        case .sort(let child, _): return "sort-\(child)"
        case .retrieve(let need): return "retrieve-\(need.id)"
        case .prepare(let need): return "prepare-\(need.id)"
        case .sizeUp(let child, let milestone): return "size-\(child)-\(milestone.size)"
        case .measure(let child): return "measure-\(child)"
        }
    }

    fileprivate var priority: Int {
        switch self {
        case .addGarments: return 0
        case .sort: return 1
        case .retrieve: return 2
        case .prepare: return 3
        case .sizeUp: return 4
        case .measure: return 5
        }
    }
}

/// Fewer actions, better ones: at most a handful of suggestions, most useful first.
public enum Briefing {
    public static func compose(
        family: [ChildProfile], items: [WardrobeItem], needs: [Need], on date: Date, limit: Int = 3
    ) -> [BriefingItem] {
        var suggestions: [(item: BriefingItem, childRank: Int)] = []
        for (rank, child) in family.enumerated() {
            let own = items.filter { $0.ownerID == child.id && $0.state == .active }
            if own.count < NeedsForecaster.minimumItemsForAdvice {
                suggestions.append((.addGarments(childID: child.id), rank))
            }
            let outgrown = own.filter { child.fit(of: $0, on: date) == .tooSmall }.map(\.id)
            if !outgrown.isEmpty {
                suggestions.append((.sort(childID: child.id, itemIDs: outgrown), rank))
            }
            let childNeeds = needs.filter { $0.childID == child.id }
            if let fromBoxes = childNeeds.first(where: { !$0.familyStock.isEmpty }) {
                suggestions.append((.retrieve(fromBoxes), rank))
            }
            if let toFind = childNeeds.first(where: { $0.stillMissing > 0 && $0.neededBy.timeIntervalSince(date) <= 60 * 86_400 }) {
                suggestions.append((.prepare(toFind), rank))
            }
            if let milestone = child.nextSize(.clothing, after: date),
               milestone.when.expected.timeIntervalSince(date) <= 56 * 86_400 {
                suggestions.append((.sizeUp(childID: child.id, milestone: milestone), rank))
            }
            if child.lastMeasuredHeightDate.map({ date.timeIntervalSince($0) > 120 * 86_400 }) ?? true {
                suggestions.append((.measure(childID: child.id), rank))
            }
        }
        return suggestions
            .sorted { ($0.item.priority, $0.childRank) < ($1.item.priority, $1.childRank) }
            .prefix(limit)
            .map(\.item)
    }
}
