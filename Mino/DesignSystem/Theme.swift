import SwiftUI
import UIKit

/// Warm and reassuring: a soft paper background, deep ink for text, a calm night blue for the
/// actions (trust, never urgency) and one gentle, warm pastel per child. Nothing in the palette
/// says "hurry" or "you did it wrong".
enum Theme {
    static let background = Color(light: 0xFAF5EC, dark: 0x17181C)
    static let card = Color(light: 0xFFFFFF, dark: 0x24262C)
    static let ink = Color(light: 0x2B3245, dark: 0xF2EFE8)
    static let secondaryText = Color(light: 0x737A87, dark: 0xA7ACB6)
    /// Neutral fill for chips and secondary buttons.
    static let chip = Color(light: 0xF0E8DC, dark: 0x30333A)
    /// The fine outline that makes a secondary action read as a button on a tinted card.
    static let outline = Color(light: 0x2B3245, dark: 0xF2EFE8).opacity(0.18)
    static let accent = Color(light: 0x34587A, dark: 0x8DB4D8)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x17181C)

    private static let childPalette: [Color] = [
        Color(light: 0x5E9CCF, dark: 0x82B6E0), // sky
        Color(light: 0x6FAA8C, dark: 0x8FC4A8), // sage
        Color(light: 0x9A8AD6, dark: 0xB4A8E6), // lavender
        Color(light: 0xD6A24E, dark: 0xE6B96E), // honey
        Color(light: 0xD48BA5, dark: 0xE4A6BC), // powder rose
        Color(light: 0x4FA6A2, dark: 0x72C0BC)  // lagoon
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
