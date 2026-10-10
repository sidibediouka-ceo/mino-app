import Foundation

/// The categories a parent actually reasons with. Underwear and socks are deliberately absent:
/// too much input for too little value.
public enum GarmentCategory: String, CaseIterable, Codable, Sendable {
    case tshirt, longSleeve, turtleneck, sweater, cardigan
    case dress, playsuit, pants, overalls, shorts, tights
    case lightJacket, coat, raincoat
    case sneakers, boots, sandals
    case pajamas, coldAccessory
    /// Baby clothes, offered up to 3 years (size 98).
    case bodysuit, longSleeveBodysuit

    public var displayName: String {
        switch self {
        case .tshirt: return "T-shirt"
        case .longSleeve: return "Haut manches longues"
        case .turtleneck: return "Sous-pull"
        case .sweater: return "Pull"
        case .cardigan: return "Gilet"
        case .dress: return "Robe"
        case .playsuit: return "Ensemble"
        case .pants: return "Pantalon"
        case .overalls: return "Salopette"
        case .shorts: return "Short & jupe"
        case .tights: return "Collant"
        case .lightJacket: return "Veste légère"
        case .coat: return "Manteau"
        case .raincoat: return "Imperméable"
        case .sneakers: return "Baskets"
        case .boots: return "Bottes"
        case .sandals: return "Sandales"
        case .pajamas: return "Pyjama"
        case .coldAccessory: return "Bonnet & gants"
        case .bodysuit: return "Body manches courtes"
        case .longSleeveBodysuit: return "Body manches longues"
        }
    }

    /// The noun with its article, used in sentences ("le pull n'a pas été porté…").
    public var definiteName: String {
        switch self {
        case .tshirt: return "le t-shirt"
        case .longSleeve: return "le haut"
        case .turtleneck: return "le sous-pull"
        case .sweater: return "le pull"
        case .cardigan: return "le gilet"
        case .dress: return "la robe"
        case .playsuit: return "l'ensemble"
        case .pants: return "le pantalon"
        case .overalls: return "la salopette"
        case .shorts: return "le short"
        case .tights: return "le collant"
        case .lightJacket: return "la veste"
        case .coat: return "le manteau"
        case .raincoat: return "l'imperméable"
        case .sneakers: return "les baskets"
        case .boots: return "les bottes"
        case .sandals: return "les sandales"
        case .pajamas: return "le pyjama"
        case .coldAccessory: return "le bonnet"
        case .bodysuit, .longSleeveBodysuit: return "le body"
        }
    }

    /// Spoken to the child in Mode enfant: "Mets ton pantalon", "Mets ta robe".
    public var childInstruction: String {
        let noun: String
        switch self {
        case .tshirt: noun = "ton t-shirt"
        case .longSleeve: noun = "ton haut"
        case .turtleneck: noun = "ton sous-pull"
        case .sweater: noun = "ton pull"
        case .cardigan: noun = "ton gilet"
        case .dress: noun = "ta robe"
        case .playsuit: noun = "ton ensemble"
        case .pants: noun = "ton pantalon"
        case .overalls: noun = "ta salopette"
        case .shorts: noun = "ton short"
        case .tights: noun = "ton collant"
        case .lightJacket: noun = "ta veste"
        case .coat: noun = "ton manteau"
        case .raincoat: noun = "ton imperméable"
        case .sneakers: noun = "tes baskets"
        case .boots: noun = "tes bottes"
        case .sandals: noun = "tes sandales"
        case .pajamas: noun = "ton pyjama"
        case .coldAccessory: noun = "ton bonnet"
        case .bodysuit, .longSleeveBodysuit: noun = "ton body"
        }
        return "Mets \(noun)"
    }

    /// Feminine nouns take "portée" in "n'a pas été portée".
    var isFeminine: Bool {
        switch self {
        case .dress, .overalls, .lightJacket: return true
        default: return false
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
        case .tshirt, .longSleeve, .turtleneck, .bodysuit, .longSleeveBodysuit: return .top
        case .pants, .overalls, .shorts: return .bottom
        case .dress, .playsuit: return .onePiece
        case .tights: return .legwear
        case .sweater, .cardigan: return .layer
        case .lightJacket, .coat, .raincoat: return .outerwear
        case .sneakers, .boots, .sandals: return .shoes
        case .coldAccessory: return .accessory
        case .pajamas: return nil
        }
    }

    /// The largest size bodies are offered in: 3 ans.
    public static let largestBodysuitSize = 98

    public var isBodysuit: Bool { self == .bodysuit || self == .longSleeveBodysuit }

    /// Whether a parent dressing a child of this size would look for this category.
    public func isOffered(forClothingSize size: Int) -> Bool {
        !isBodysuit || size <= Self.largestBodysuitSize
    }

    /// Whether the outfit engine should avoid repeating it on consecutive days (laundry).
    var rotates: Bool {
        switch slot {
        case .top, .bottom, .onePiece, .layer, .legwear: return true
        default: return false
        }
    }
}
