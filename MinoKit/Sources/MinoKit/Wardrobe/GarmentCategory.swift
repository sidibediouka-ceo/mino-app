import Foundation

/// The categories a parent actually reasons with. Underwear and socks are deliberately absent:
/// too much input for too little value.
public enum GarmentCategory: String, CaseIterable, Codable, Sendable {
    case tshirt, longSleeve, sweater, dress, pants, shorts
    case lightJacket, coat, raincoat
    case sneakers, boots, sandals
    case pajamas, coldAccessory

    public var displayName: String {
        switch self {
        case .tshirt: return "T-shirt"
        case .longSleeve: return "Haut manches longues"
        case .sweater: return "Pull & gilet"
        case .dress: return "Robe"
        case .pants: return "Pantalon"
        case .shorts: return "Short & jupe"
        case .lightJacket: return "Veste légère"
        case .coat: return "Manteau"
        case .raincoat: return "Imperméable"
        case .sneakers: return "Baskets"
        case .boots: return "Bottes"
        case .sandals: return "Sandales"
        case .pajamas: return "Pyjama"
        case .coldAccessory: return "Bonnet & gants"
        }
    }

    /// The noun with its article, used in sentences ("le pull n'a pas été porté…").
    public var definiteName: String {
        switch self {
        case .tshirt: return "le t-shirt"
        case .longSleeve: return "le haut"
        case .sweater: return "le pull"
        case .dress: return "la robe"
        case .pants: return "le pantalon"
        case .shorts: return "le short"
        case .lightJacket: return "la veste"
        case .coat: return "le manteau"
        case .raincoat: return "l'imperméable"
        case .sneakers: return "les baskets"
        case .boots: return "les bottes"
        case .sandals: return "les sandales"
        case .pajamas: return "le pyjama"
        case .coldAccessory: return "le bonnet"
        }
    }

    public var sizeKind: SizeKind {
        switch self {
        case .sneakers, .boots, .sandals: return .shoes
        default: return .clothing
        }
    }

    /// Where the garment goes in a day outfit; pyjamas are never part of one.
    public var slot: OutfitSlot? {
        switch self {
        case .tshirt, .longSleeve: return .top
        case .pants, .shorts: return .bottom
        case .dress: return .dress
        case .sweater: return .layer
        case .lightJacket, .coat, .raincoat: return .outerwear
        case .sneakers, .boots, .sandals: return .shoes
        case .coldAccessory: return .accessory
        case .pajamas: return nil
        }
    }

    /// Whether the outfit engine should avoid repeating it on consecutive days (laundry).
    var rotates: Bool {
        switch slot {
        case .top, .bottom, .dress, .layer: return true
        default: return false
        }
    }
}
