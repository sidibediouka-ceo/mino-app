import Foundation
import MinoKit
import SwiftData

/// Keeps one outfit per child and day, and turns the parent's gestures into learning.
///
/// Days are planned in order: tomorrow counts today's planned outfit as worn, so it never
/// repeats it, whether or not today's outfit was handed over in Mode enfant.
@MainActor
struct DayPlanner {
    let family: FamilySnapshot
    let context: ModelContext
    let calendar: Calendar

    private var engine: OutfitEngine { OutfitEngine(calendar: calendar) }

    /// Makes sure every child has an up-to-date plan for each of `days` (in chronological order).
    ///
    /// A plan the parent has not touched follows the latest weather and wardrobe; a plan they
    /// adjusted is kept as they left it, unless one of its garments is no longer available.
    func ensurePlans(for days: [Date], forecast: (Date) -> DayForecast) {
        // A past day's outfit is assumed worn: parents never have to confirm anything.
        let today = calendar.startOfDay(for: .now)
        for plan in allPlans where plan.confirmedAt == nil && plan.day < today {
            confirm(plan)
        }
        for day in days {
            for child in family.children {
                if let plan = (child.plans ?? []).first(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
                    guard plan.confirmedAt == nil else { continue }
                    let untouched = plan.piecesRaw == plan.proposedRaw
                    let missingGarment = plan.outfit.pieces.contains { !isAvailable($0.itemID, for: child) }
                    if untouched || missingGarment {
                        propose(plan, for: child, forecast: forecast(day))
                    }
                } else {
                    let plan = PlannedOutfit(day: calendar.startOfDay(for: day))
                    context.insert(plan)
                    plan.child = child
                    plan.context = child.routine.context(on: day, calendar: calendar)
                    propose(plan, for: child, forecast: forecast(day))
                }
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
            for: slot, in: outfit, child: profile, items: items(before: plan.day), weather: forecast, context: plan.context
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

    /// The child wore it (Mode enfant finished, or the day is over): update rotation and learn
    /// from the parent's swaps.
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

    private var allPlans: [PlannedOutfit] {
        family.children.flatMap { $0.plans ?? [] }
    }

    /// The wardrobe as it will be on `day`: garments planned for earlier days count as worn.
    private func items(before day: Date) -> [WardrobeItem] {
        var plannedOn: [UUID: Date] = [:]
        for plan in allPlans where plan.confirmedAt == nil && plan.day < day {
            for piece in plan.outfit.pieces {
                plannedOn[piece.itemID] = max(plannedOn[piece.itemID] ?? plan.day, plan.day)
            }
        }
        return family.items.map { item in plannedOn[item.id].map(item.worn(on:)) ?? item }
    }

    /// Writes only what changed, so that re-planning an untouched day is a no-op.
    private func propose(_ plan: PlannedOutfit, for child: Child, forecast: DayForecast) {
        let profile = family.profile(child.id) ?? child.profile
        let outfit = engine.propose(child: profile, items: items(before: plan.day), weather: forecast, context: plan.context)
        guard outfit != plan.outfit || plan.piecesRaw != plan.proposedRaw else { return }
        plan.outfit = outfit
        plan.proposedRaw = plan.piecesRaw
        plan.skippedIDs = []
    }

    private func isAvailable(_ id: UUID, for child: Child) -> Bool {
        guard let garment = family.garment(id) else { return false }
        return garment.state == .active && garment.owner?.id == child.id
    }
}
