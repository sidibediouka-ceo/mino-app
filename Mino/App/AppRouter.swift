import Foundation
import Observation

enum AppTab: Hashable {
    case today, wardrobe, growth
}

/// Lets a suggestion on one screen lead straight to the place where it is acted upon.
@Observable
final class AppRouter {
    var tab: AppTab = .today
    /// The child the Growth screen should show when opened from a suggestion.
    var focusedChildID: UUID?

    func showGrowth(of childID: UUID) {
        focusedChildID = childID
        tab = .growth
    }
}
