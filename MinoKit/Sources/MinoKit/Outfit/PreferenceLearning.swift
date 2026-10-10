import Foundation

/// The invisible copilot: each confirmed outfit nudges preferences, nothing is ever asked.
public enum PreferenceLearning {
    /// Affinity deltas after the parent confirmed what the child actually wore.
    /// Kept suggestions gain a little, chosen replacements gain more, rejected ones lose.
    public static func affinityChanges(proposed: [OutfitPiece], worn: [OutfitPiece]) -> [UUID: Double] {
        let proposedIDs = Set(proposed.map(\.itemID))
        let wornIDs = Set(worn.map(\.itemID))
        var changes: [UUID: Double] = [:]
        for id in proposedIDs.intersection(wornIDs) { changes[id] = 0.15 }
        for id in wornIDs.subtracting(proposedIDs) { changes[id] = 0.3 }
        for id in proposedIDs.subtracting(wornIDs) { changes[id] = -0.3 }
        return changes
    }

    public static func applying(_ delta: Double, to affinity: Double) -> Double {
        min(2, max(-2, affinity + delta))
    }
}
