import Foundation
import SwiftData

/// A parent's "J'en ai assez" to one of Mino's suggestions: Mino trusts them and stops
/// suggesting it for the season.
@Model
final class CoveredNeed {
    /// `Need.id`: child, kind of garment and season.
    var needID: String = ""
    var coveredAt: Date = Date.now

    init(needID: String) {
        self.needID = needID
    }

    /// A season later, the question is worth asking again.
    var isCurrent: Bool { Date.now.timeIntervalSince(coveredAt) < 150 * 86_400 }
}
