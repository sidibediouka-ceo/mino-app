import Foundation
import MinoKit
import SwiftData

/// Keeps one stable outfit per child and day, and turns the parent's gestures into learning.
@MainActor
struct DayPlanner {
    let family: FamilySnapshot
    let context: ModelContext
    let calendar: Calendar

    private var engine: OutfitEngine { OutfitEngine(calendar: calendar) }

    /// Makes sure every child has an up-to-date plan for `day`.
    func ensurePlans(for day: Date, forecast: DayForecast) {
        for child in family.children {
            if let plan = (child.plans ?? []).first(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
                guard plan.confirmedAt == nil else { continue }
                let outfit = plan.outfit
                let betterForecast = plan.basedOnEstimate && !forecast.isEstimate
                let missingGarment = outfit.pieces.contains { !isAvailable($0.itemID, for: child) }
                let untouchedWithGaps = !outfit.gaps.isEmpty && plan.piecesRaw == plan.proposedRaw
                if betterForecast || missingGarment || untouchedWithGaps {
                    propose(plan, for: child, forecast: forecast)
                }
            } else {
                let plan = PlannedOutfit(day: calendar.startOfDay(for: day))
                context.insert(plan)
                plan.child = child
                plan.context = child.routine.context(on: day, calendar: calendar)
                propose(plan, for: child, forecast: forecast)
            }
        }
    }

    /// Replaces one piece with the next best alternative, cycling through all of them.
    func swap(_ slot: OutfitSlot, in plan: PlannedOutfit, forecast: DayForecast) {
        guard let child = plan.child, let profile = family.profile(child.id) else { return }
        let outfit = plan.outfit
        if let current = outfit.pieces.first(where: { $0.slot == slot })?.itemID {
            plan.skippedIDs.append(current)
        }
        let options = engine.alternatives(
            for: slot, in: outfit, child: profile, items: family.items, weather: forecast, context: plan.context
        )
        guard let next = options.first(where: { !plan.skippedIDs.contains($0) }) ?? options.first else { return }
        if options.allSatisfy({ plan.skippedIDs.contains($0) }) { plan.skippedIDs = [] }
        plan.outfit = outfit.replacing(slot, with: next)
    }

    /// A new context for the day; Mino remembers it for this weekday.
    func setContext(_ dayContext: DayContext, for plan: PlannedOutfit, forecast: DayForecast) {
        guard let child = plan.child else { return }
        child.routine = child.routine.learning(dayContext, on: plan.day, calendar: calendar)
        plan.context = dayContext
        propose(plan, for: child, forecast: forecast)
    }

    /// The child wore it: update rotation and learn from the parent's swaps.
    func confirm(_ plan: PlannedOutfit) {
        guard plan.confirmedAt == nil else { return }
        let worn = plan.outfit.pieces
        for (id, delta) in PreferenceLearning.affinityChanges(proposed: plan.proposedPieces, worn: worn) {
            guard let garment = family.garment(id) else { continue }
            garment.affinity = PreferenceLearning.applying(delta, to: garment.affinity)
        }
        for piece in worn {
            guard let garment = family.garment(piece.itemID) else { continue }
            garment.lastWornAt = plan.day
            garment.wearCount += 1
        }
        plan.confirmedAt = .now
    }

    private func propose(_ plan: PlannedOutfit, for child: Child, forecast: DayForecast) {
        let profile = family.profile(child.id) ?? child.profile
        plan.outfit = engine.propose(child: profile, items: family.items, weather: forecast, context: plan.context)
        plan.proposedRaw = plan.piecesRaw
        plan.skippedIDs = []
        plan.basedOnEstimate = forecast.isEstimate
    }

    private func isAvailable(_ id: UUID, for child: Child) -> Bool {
        guard let garment = family.garment(id) else { return false }
        return garment.state == .active && garment.owner?.id == child.id
    }
}
