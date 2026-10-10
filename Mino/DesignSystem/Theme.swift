import SwiftUI
import UIKit

/// Warm and joyful rather than corporate: a soft paper background, deep ink for text,
/// a coral accent for the actions that matter, and one bright colour per child.
enum Theme {
    static let background = Color(light: 0xFBF6EE, dark: 0x16171B)
    static let card = Color(light: 0xFFFFFF, dark: 0x23252B)
    static let ink = Color(light: 0x22293A, dark: 0xF3F0EA)
    static let secondaryText = Color(light: 0x6E7584, dark: 0xA5AAB5)
    /// Neutral fill for chips and secondary buttons.
    static let chip = Color(light: 0xF1EAE0, dark: 0x30333A)
    static let accent = Color(light: 0xEE6A47, dark: 0xFF8664)
    static let onAccent = Color.white

    private static let childPalette: [Color] = [
        Color(light: 0xEE6A47, dark: 0xFF8664), // coral
        Color(light: 0x3A8FD9, dark: 0x5EA9EE), // sky
        Color(light: 0x2BA67F, dark: 0x45C297), // mint
        Color(light: 0x8B6FE8, dark: 0xA58FF3), // lilac
        Color(light: 0xE5A11A, dark: 0xF2B83F), // sunflower
        Color(light: 0xE0598F, dark: 0xF07AA8)  // rose
    ]

    /// Each child keeps their colour everywhere in the app (their order of creation decides it).
    static func color(forChildAt index: Int) -> Color {
        childPalette[index % childPalette.count]
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

extension Array where Element == Child {
    /// The colour of `child`, stable as long as the family does not change.
    func color(of child: Child) -> Color {
        Theme.color(forChildAt: firstIndex { $0.id == child.id } ?? 0)
    }
}
