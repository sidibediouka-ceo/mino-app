import Foundation

public struct RGBColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum GarmentColor: String, CaseIterable, Codable, Sendable {
    case white, grey, black, beige, brown, navy, denim
    case red, pink, orange, yellow, green, blue, purple
    case multicolor

    public var displayName: String {
        switch self {
        case .white: return "Blanc"
        case .grey: return "Gris"
        case .black: return "Noir"
        case .beige: return "Beige"
        case .brown: return "Marron"
        case .navy: return "Marine"
        case .denim: return "Jean"
        case .red: return "Rouge"
        case .pink: return "Rose"
        case .orange: return "Orange"
        case .yellow: return "Jaune"
        case .green: return "Vert"
        case .blue: return "Bleu"
        case .purple: return "Violet"
        case .multicolor: return "Multicolore"
        }
    }

    /// Representative swatch; `multicolor` has none.
    public var swatch: RGBColor? {
        switch self {
        case .white: return RGBColor(red: 0.96, green: 0.96, blue: 0.94)
        case .grey: return RGBColor(red: 0.58, green: 0.58, blue: 0.60)
        case .black: return RGBColor(red: 0.12, green: 0.12, blue: 0.13)
        case .beige: return RGBColor(red: 0.85, green: 0.78, blue: 0.66)
        case .brown: return RGBColor(red: 0.47, green: 0.33, blue: 0.22)
        case .navy: return RGBColor(red: 0.13, green: 0.19, blue: 0.36)
        case .denim: return RGBColor(red: 0.32, green: 0.45, blue: 0.62)
        case .red: return RGBColor(red: 0.80, green: 0.18, blue: 0.20)
        case .pink: return RGBColor(red: 0.94, green: 0.62, blue: 0.72)
        case .orange: return RGBColor(red: 0.93, green: 0.52, blue: 0.20)
        case .yellow: return RGBColor(red: 0.96, green: 0.83, blue: 0.30)
        case .green: return RGBColor(red: 0.35, green: 0.58, blue: 0.36)
        case .blue: return RGBColor(red: 0.30, green: 0.56, blue: 0.86)
        case .purple: return RGBColor(red: 0.55, green: 0.38, blue: 0.70)
        case .multicolor: return nil
        }
    }

    /// Neutrals go with everything.
    public var isNeutral: Bool {
        switch self {
        case .white, .grey, .black, .beige, .brown, .navy, .denim: return true
        default: return false
        }
    }

    /// How well two colours sit together in one outfit (negative means they clash).
    static func harmony(_ lhs: GarmentColor, _ rhs: GarmentColor) -> Double {
        if lhs == .multicolor && rhs == .multicolor { return -1.5 }
        if lhs.isNeutral || rhs.isNeutral { return 0.5 }
        if lhs == rhs { return 0.2 }
        if lhs == .multicolor || rhs == .multicolor { return -1 }
        return -0.8
    }

    /// The dominant named colour among the pixels of a cut-out garment.
    /// Returns `multicolor` when no colour covers at least 40 % of the pixels.
    public static func dominant(in pixels: [RGBColor]) -> GarmentColor? {
        guard !pixels.isEmpty else { return nil }
        let named = allCases.compactMap { color in color.swatch.map { (color, $0) } }
        var counts: [GarmentColor: Int] = [:]
        for pixel in pixels {
            guard let nearest = named.min(by: { distance(pixel, $0.1) < distance(pixel, $1.1) }) else { continue }
            counts[nearest.0, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return Double(top.value) / Double(pixels.count) >= 0.4 ? top.key : .multicolor
    }

    /// "Redmean" weighted distance, a cheap approximation of perceived colour difference.
    private static func distance(_ a: RGBColor, _ b: RGBColor) -> Double {
        let meanRed = (a.red + b.red) / 2
        let dr = a.red - b.red, dg = a.green - b.green, db = a.blue - b.blue
        return (2 + meanRed) * dr * dr + 4 * dg * dg + (3 - meanRed) * db * db
    }
}
