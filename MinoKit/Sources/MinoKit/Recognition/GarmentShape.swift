import Foundation

/// The silhouette of a background-free garment photo. Apple's general image classifier knows
/// "clothing" far better than it tells a jacket from jeans; the outline settles the family
/// (shoes, legs, a top…) and the classifier picks within it.
public struct GarmentShape: Equatable, Sendable {
    /// What the outline alone says about the garment.
    public enum Family: Equatable, Sendable {
        /// Wider than tall: a pair of shoes seen from the side.
        case shoes
        /// Very long and narrow: tights or leggings.
        case tights
        /// Two legs, long: trousers, overalls, footed pyjamas.
        case longLegs
        /// Two legs, short.
        case shortLegs
        /// Taller than wide, no legs: a dress, a sleeveless vest, a long coat.
        case long
        /// About as tall as wide: tops, jackets, skirts.
        case upper
    }

    /// Height divided by width of the garment's bounding box.
    public let aspect: Double
    /// Share of the lower rows where the centre is empty between two filled parts.
    let legs: Double
    /// Widths at a quarter, half and 85 % of the height, as fractions of the garment's width.
    let upperWidth: Double
    let middleWidth: Double
    let lowerWidth: Double

    /// - Parameters:
    ///   - mask: the garment's opaque pixels, row by row, cropped to the garment and sampled on a
    ///     small grid (24 × 24 is plenty).
    ///   - aspect: height divided by width of the garment before sampling.
    public init?(mask: [[Bool]], aspect: Double) {
        let rows = mask.count
        guard rows >= 8, let columns = mask.first?.count, columns >= 8, aspect > 0 else { return nil }
        self.aspect = aspect
        let width = { (row: Int) in Double(mask[row].filter { $0 }.count) / Double(columns) }
        upperWidth = width(rows / 4)
        middleWidth = width(rows / 2)
        lowerWidth = width(rows * 85 / 100)
        let centre = (columns / 2 - 1)...(columns / 2)
        let lower = (rows * 6 / 10)..<(rows * 95 / 100)
        let legRows = lower.filter { row in
            centre.contains { !mask[row][$0] } && Self.segments(in: mask[row]) >= 2
        }
        legs = Double(legRows.count) / Double(max(1, lower.count))
    }

    public var family: Family {
        if aspect < 0.8 && legs < 0.5 { return .shoes }
        if aspect >= 2.8 { return .tights }
        if legs >= 0.5 { return aspect >= 1.3 ? .longLegs : .shortLegs }
        if aspect >= 1.25 { return .long }
        return .upper
    }

    /// Categories that can have this outline, most likely first.
    public var likelyCategories: [GarmentCategory] {
        switch family {
        case .shoes:
            return [.sneakers, .boots, .sandals]
        case .tights:
            return [.tights, .pants]
        case .longLegs:
            return [.pants, .overalls, .pajamas, .tights, .playsuit]
        case .shortLegs:
            return [.shorts, .playsuit]
        case .long:
            // A skirt that flares out is a dress; a straight one is a vest or a long coat.
            let flares = lowerWidth >= middleWidth * 1.2
            return flares
                ? [.dress, .cardigan, .coat, .raincoat, .playsuit, .pajamas]
                : [.cardigan, .coat, .raincoat, .dress, .playsuit, .pajamas]
        case .upper:
            // Short sleeves stick out at the shoulders, wider than the body below.
            let shortSleeves = upperWidth >= middleWidth + 2 / 24
            let tops: [GarmentCategory] = shortSleeves
                ? [.tshirt, .bodysuit, .longSleeve, .longSleeveBodysuit]
                : [.longSleeve, .longSleeveBodysuit, .tshirt, .bodysuit]
            return tops + [.sweater, .cardigan, .lightJacket, .coat, .raincoat, .turtleneck, .shorts, .dress, .coldAccessory]
        }
    }

    private static func segments(in row: [Bool]) -> Int {
        var count = 0
        var inside = false
        for filled in row {
            if filled && !inside { count += 1 }
            inside = filled
        }
        return count
    }
}
