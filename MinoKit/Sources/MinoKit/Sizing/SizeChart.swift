import Foundation

public enum SizeKind: Sendable {
    /// EN 13402 / Asian convention: the stature in centimetres the garment is cut for.
    case clothing
    /// EU shoe size.
    case shoes
}

/// The single source of truth for sizes. Mino reasons in centimetres, like Japan, China and
/// EN 13402, and shows the French age label as a familiar landmark.
public enum SizeChart {
    public static let clothingSizes: [Int] = [
        50, 56, 62, 68, 74, 80, 86, 92, 98, 104, 110, 116, 122, 128, 134, 140, 146, 152, 158, 164, 170
    ]

    public static let shoeSizes: [Int] = Array(16...40)

    private static let ageLabels: [Int: String] = [
        50: "Naissance", 56: "1 mois", 62: "3 mois", 68: "6 mois", 74: "12 mois", 80: "18 mois",
        86: "2 ans", 92: "2 ans ½", 98: "3 ans", 104: "4 ans", 110: "5 ans", 116: "6 ans",
        122: "7 ans", 128: "8 ans", 134: "9 ans", 140: "10 ans", 146: "11 ans", 152: "12 ans",
        158: "13 ans", 164: "14 ans", 170: "16 ans"
    ]

    /// Age in months that each size is usually labelled with, used to read "4 ans" or "18M" tags.
    private static let ageInMonthsBySize: [(months: Int, size: Int)] = [
        (0, 50), (1, 56), (3, 62), (6, 68), (12, 74), (18, 80), (24, 86), (30, 92), (36, 98),
        (48, 104), (60, 110), (72, 116), (84, 122), (96, 128), (108, 134), (120, 140),
        (132, 146), (144, 152), (156, 158), (168, 164), (192, 170)
    ]

    public static func ageLabel(forClothingSize size: Int) -> String {
        ageLabels[snapClothing(Double(size))] ?? "\(size) cm"
    }

    /// "4 ans · 104 cm", or "Pointure 27".
    public static func label(size: Int, kind: SizeKind) -> String {
        switch kind {
        case .clothing: return "\(ageLabel(forClothingSize: size)) · \(size) cm"
        case .shoes: return "Pointure \(size)"
        }
    }

    public static func shortLabel(size: Int, kind: SizeKind) -> String {
        switch kind {
        case .clothing: return ageLabel(forClothingSize: size)
        case .shoes: return "P. \(size)"
        }
    }

    /// The nearest standard size; ties go to the larger size.
    public static func snapClothing(_ value: Double) -> Int {
        clothingSizes.min { lhs, rhs in
            let left = abs(Double(lhs) - value), right = abs(Double(rhs) - value)
            return left == right ? lhs > rhs : left < right
        } ?? clothingSizes[0]
    }

    public static func clothingSize(forAgeInMonths months: Int) -> Int {
        ageInMonthsBySize.min { abs($0.months - months) < abs($1.months - months) }?.size ?? clothingSizes[0]
    }

    /// The size a child of this stature wears today.
    public static func wornClothingSize(forHeight height: Double) -> Int {
        clothingSizes.first { Double($0) >= height - 2 } ?? clothingSizes[clothingSizes.count - 1]
    }

    /// The size after `size` on the standard grid.
    public static func nextClothingSize(after size: Int) -> Int? {
        clothingSizes.first { $0 > size }
    }

    /// The shoe size a child wears when the projection reads `estimate`.
    public static func wornShoeSize(forEstimate estimate: Double) -> Int {
        let size = Int(estimate.rounded(.up))
        return min(max(size, shoeSizes[0]), shoeSizes[shoeSizes.count - 1])
    }

    /// Inverse of `wornClothingSize`: a plausible stature for a child who currently wears `size`.
    public static func typicalHeight(wearing size: Int) -> Double {
        Double(size) - 3
    }
}
