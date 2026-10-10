import Foundation

/// Maps on-device image classification labels to a garment category.
/// The guess is only a pre-selection: the parent confirms with one tap.
public enum CategoryGuess {
    /// Ordered from most to least specific so that "raincoat" wins over "coat" and "t_shirt" over "shirt".
    private static let keywords: [(String, GarmentCategory)] = [
        ("raincoat", .raincoat), ("poncho", .raincoat), ("rain", .raincoat),
        ("t_shirt", .tshirt), ("t-shirt", .tshirt), ("tshirt", .tshirt), ("jersey", .tshirt),
        ("sweatshirt", .sweater), ("sweater", .sweater), ("cardigan", .sweater), ("hoodie", .sweater),
        ("jumper", .sweater), ("fleece", .sweater), ("knit", .sweater),
        ("pajama", .pajamas), ("pyjama", .pajamas), ("sleepwear", .pajamas), ("nightwear", .pajamas),
        ("jean", .pants), ("trouser", .pants), ("legging", .pants), ("pant", .pants),
        ("short", .shorts), ("skirt", .shorts),
        ("dress", .dress), ("gown", .dress),
        ("parka", .coat), ("anorak", .coat), ("coat", .coat),
        ("jacket", .lightJacket), ("blazer", .lightJacket), ("windbreaker", .lightJacket),
        ("boot", .boots), ("sandal", .sandals),
        ("sneaker", .sneakers), ("trainer", .sneakers), ("shoe", .sneakers), ("footwear", .sneakers),
        ("beanie", .coldAccessory), ("mitten", .coldAccessory), ("glove", .coldAccessory),
        ("scarf", .coldAccessory), ("hat", .coldAccessory),
        ("shirt", .longSleeve), ("blouse", .longSleeve), ("top", .longSleeve)
    ]

    public static func category(fromLabels labels: [(identifier: String, confidence: Float)]) -> GarmentCategory? {
        var scores: [GarmentCategory: Float] = [:]
        for label in labels where label.confidence >= 0.1 {
            let identifier = label.identifier.lowercased()
            if let match = keywords.first(where: { identifier.contains($0.0) }) {
                scores[match.1, default: 0] += label.confidence
            }
        }
        guard let best = scores.max(by: { $0.value < $1.value }), best.value >= 0.15 else { return nil }
        return best.key
    }
}
