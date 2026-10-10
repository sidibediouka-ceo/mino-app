import Foundation

/// What to do with a garment that no longer fits.
public enum Destination: Equatable, Sendable {
    /// Give it to a sibling, now or when it fits.
    case sibling(UUID, fitsFrom: Date?)
    /// Keep it in the family boxes for a sibling who will grow into it later.
    case store
    case donate
    case sell
}

public enum LifecycleAdvisor {
    /// Siblings first, then the boxes, then a second life outside the family.
    public static func recommend(for item: WardrobeItem, family: [ChildProfile], on date: Date) -> Destination {
        let others = family.filter { $0.id != item.ownerID }
        if let now = others.first(where: { $0.fit(of: item, on: date) == .fits }) {
            return .sibling(now.id, fitsFrom: nil)
        }
        let upcoming = others.compactMap { child -> (ChildProfile, Date)? in
            let fit = child.fit(of: item, on: date)
            guard fit == .roomy || fit == .tooBig, let estimate = child.dateItemFits(item, from: date) else { return nil }
            return (child, estimate.expected)
        }
        .min { $0.1 < $1.1 }
        if let (child, fitsFrom) = upcoming {
            let months = fitsFrom.timeIntervalSince(date) / (30.4 * 86_400)
            return months <= 12 ? .sibling(child.id, fitsFrom: fitsFrom) : .store
        }
        switch item.category {
        case .coat, .raincoat, .boots, .sneakers: return .sell
        default: return item.occasion == .dressy ? .sell : .donate
        }
    }
}
