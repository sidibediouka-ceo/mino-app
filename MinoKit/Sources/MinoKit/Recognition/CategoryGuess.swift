import Foundation

/// Maps on-device image classification labels to a garment category.
/// The guess is only a pre-selection: the parent confirms with one tap.
public enum CategoryGuess {
    /// Ordered from most to least specific so that "raincoat" wins over "coat" and "t_shirt" over "shirt".
    private static let keywords: [(String, GarmentCategory)] = [
        ("onesie", .bodysuit), ("bodysuit", .bodysuit), ("babygrow", .bodysuit),
        ("raincoat", .raincoat), ("poncho", .raincoat), ("rain", .raincoat),
        ("t_shirt", .tshirt), ("t-shirt", .tshirt), ("tshirt", .tshirt), ("jersey", .tshirt),
        ("turtleneck", .turtleneck), ("polo neck", .turtleneck),
        ("cardigan", .cardigan), ("vest", .cardigan), ("waistcoat", .cardigan), ("gilet", .cardigan),
        ("tights", .tights), ("pantyhose", .tights), ("stocking", .tights),
        ("overall", .overalls), ("dungaree", .overalls),
        ("jumpsuit", .playsuit), ("romper", .playsuit), ("tracksuit", .playsuit),
        ("sweatshirt", .sweater), ("sweater", .sweater), ("hoodie", .sweater),
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

    /// The families Mino's own classifier (MinoGarmentClassifier) tells apart, and the categories
    /// each one covers, most common first.
    public static let classifierFamilies: [String: [GarmentCategory]] = [
        "tshirt": [.tshirt, .bodysuit],
        "longsleeve": [.longSleeve, .turtleneck, .longSleeveBodysuit],
        "knit": [.sweater, .cardigan],
        "pants": [.pants, .overalls, .pajamas],
        "shorts_skirt": [.shorts],
        "dress": [.dress, .playsuit],
        "outerwear": [.lightJacket, .coat, .raincoat],
        "shoes": [.sneakers, .boots, .sandals],
        "hat": [.coldAccessory],
        "bodysuit": [.bodysuit, .longSleeveBodysuit],
        "tights": [.tights]
    ]

    /// Categories suggested by the labels, most likely first. Weak signals are dropped.
    ///
    /// Mino's classifier knows children's garment families well; Apple's general classifier
    /// adds detail within a family ("raincoat", "cardigan"); the outline rules out what cannot
    /// have that shape.
    ///
    /// With the garment's outline, categories that cannot have that shape are pushed down and
    /// those that can are lifted, so that "jeans" on a denim jacket no longer reads as trousers
    /// and a photo the classifier could not read still gets a sensible first guess.
    public static func ranked(
        fromLabels labels: [(identifier: String, confidence: Float)],
        shape: GarmentShape? = nil,
        families: [(identifier: String, confidence: Float)] = []
    ) -> [GarmentCategory] {
        var scores: [GarmentCategory: Float] = [:]
        for family in families {
            for (rank, category) in (classifierFamilies[family.identifier] ?? []).enumerated() {
                scores[category, default: 0] += family.confidence * (rank == 0 ? 1.2 : 0.7)
            }
        }
        for label in labels where label.confidence >= 0.1 {
            let identifier = label.identifier.lowercased()
            if let match = keywords.first(where: { identifier.contains($0.0) }) {
                scores[match.1, default: 0] += label.confidence
            }
        }
        if let shape {
            let likely = shape.likelyCategories
            for category in GarmentCategory.allCases {
                if let rank = likely.firstIndex(of: category) {
                    scores[category, default: 0] += 0.35 - 0.04 * Float(rank)
                } else if let score = scores[category] {
                    scores[category] = score - 0.6
                }
            }
        }
        return scores
            .filter { $0.value >= 0.15 }
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .map(\.key)
    }
}
