import Foundation
import MinoKit
import SwiftData

/// The outfit planned for one child on one day. Kept so the plan stays stable while the
/// parent swaps pieces, and so that confirming it can teach Mino.
@Model
final class PlannedOutfit {
    var day: Date = Date.now
    var contextRaw: String = DayContext.school.rawValue
    /// Current pieces, as `OutfitPiece.rawValue`.
    var piecesRaw: [String] = []
    /// What Mino first proposed, to learn from the parent's swaps.
    var proposedRaw: [String] = []
    /// Garments the parent swapped away today, so swapping cycles through alternatives.
    var skippedIDs: [UUID] = []
    var gapsRaw: [String] = []
    var reasons: [String] = []
    var confirmedAt: Date?
    /// What the day is for, when the parent prepared the outfit ahead ("Soirée chez Lina").
    var note: String = ""
    var child: Child?

    init(day: Date) {
        self.day = day
    }

    var context: DayContext {
        get { DayContext(rawValue: contextRaw) ?? .school }
        set { contextRaw = newValue.rawValue }
    }

    var outfit: Outfit {
        get {
            Outfit(
                pieces: piecesRaw.compactMap(OutfitPiece.init(rawValue:)),
                gaps: gapsRaw.compactMap(OutfitSlot.init(rawValue:)),
                reasons: reasons
            )
        }
        set {
            piecesRaw = newValue.pieces.map(\.rawValue)
            gapsRaw = newValue.gaps.map(\.rawValue)
            reasons = newValue.reasons
        }
    }

    /// Chosen by the parent rather than proposed by Mino: kept exactly as it is.
    var isPreparedByParent: Bool { proposedRaw.isEmpty && !piecesRaw.isEmpty }

    var proposedPieces: [OutfitPiece] {
        proposedRaw.compactMap(OutfitPiece.init(rawValue:))
    }
}
