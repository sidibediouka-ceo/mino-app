import SwiftUI
import UIKit

/// Mino's palette: a calm forest green, a warm cream and a soft sage, with a terracotta
/// accent kept for rare, happy moments. Every colour adapts to dark mode.
enum Theme {
    static let forest = Color(light: 0x1E3A34, dark: 0xCFE0D6)
    static let sage = Color(light: 0xA7B69A, dark: 0x8FA382)
    static let background = Color(light: 0xF5F2ED, dark: 0x141A17)
    static let card = Color(light: 0xFFFFFF, dark: 0x1F2723)
    static let secondaryText = Color(light: 0x6B7C73, dark: 0x9DADA4)
    static let onForest = Color(light: 0xF5F2ED, dark: 0x141A17)
    static let terracotta = Color(light: 0xC96F48, dark: 0xE39A78)
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
