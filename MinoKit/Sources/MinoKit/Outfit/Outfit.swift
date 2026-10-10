import Foundation

/// Slots in the order a child puts them on.
public enum OutfitSlot: String, CaseIterable, Codable, Sendable {
    case bottom, top, dress, layer, shoes, outerwear, accessory

    public var displayName: String {
        switch self {
        case .bottom: return "Bas"
        case .top: return "Haut"
        case .dress: return "Robe"
        case .layer: return "Pull"
        case .shoes: return "Chaussures"
        case .outerwear: return "Manteau"
        case .accessory: return "Accessoire"
        }
    }

    var dressingOrder: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public struct OutfitPiece: Equatable, Sendable {
    public let slot: OutfitSlot
    public let itemID: UUID

    public init(slot: OutfitSlot, itemID: UUID) {
        self.slot = slot
        self.itemID = itemID
    }

    /// "top=UUID", the persisted form.
    public var rawValue: String { "\(slot.rawValue)=\(itemID.uuidString)" }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "=")
        guard parts.count == 2, let slot = OutfitSlot(rawValue: String(parts[0])), let id = UUID(uuidString: String(parts[1])) else {
            return nil
        }
        self.init(slot: slot, itemID: id)
    }
}

public struct Outfit: Equatable, Sendable {
    /// Ordered for getting dressed.
    public let pieces: [OutfitPiece]
    /// Slots that should be filled but for which nothing suitable fits.
    public let gaps: [OutfitSlot]
    /// One or two short sentences explaining the choice.
    public let reasons: [String]

    public init(pieces: [OutfitPiece], gaps: [OutfitSlot], reasons: [String]) {
        self.pieces = pieces.sorted { $0.slot.dressingOrder < $1.slot.dressingOrder }
        self.gaps = gaps
        self.reasons = reasons
    }

    public func replacing(_ slot: OutfitSlot, with itemID: UUID) -> Outfit {
        let others = pieces.filter { $0.slot != slot }
        return Outfit(pieces: others + [OutfitPiece(slot: slot, itemID: itemID)], gaps: gaps, reasons: reasons)
    }
}
