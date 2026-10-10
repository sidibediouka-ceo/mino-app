import Foundation
import MinoKit

/// How a lifecycle destination reads in the interface.
enum DestinationLabel {
    static func text(_ destination: Destination, children: [Child]) -> String {
        switch destination {
        case .sibling(let id, let fitsFrom):
            let name = children.first { $0.id == id }?.name ?? "un frère ou une sœur"
            guard let fitsFrom else { return "Pour \(name)" }
            return "Pour \(name), vers \(Formatting.period(fitsFrom))"
        case .store: return "Ranger dans les cartons"
        case .donate: return "Donner"
        case .sell: return "Vendre"
        }
    }

    static func symbol(_ destination: Destination) -> String {
        switch destination {
        case .sibling: return "figure.2.and.child.holdinghands"
        case .store: return "shippingbox"
        case .donate: return "heart"
        case .sell: return "tag"
        }
    }

    /// Every destination a parent can choose for a garment, siblings first.
    static func all(for garment: Garment, children: [Child]) -> [Destination] {
        recipients(for: garment, children: children).map { Destination.sibling($0.id, fitsFrom: nil) } + [.store, .donate, .sell]
    }

    /// The children a garment can be handed to: everyone but the child who wears it now.
    static func recipients(for garment: Garment, children: [Child]) -> [Child] {
        children.filter { $0.id != garment.owner?.id || garment.state != .active }
    }
}
