import MinoKit
import SwiftData
import SwiftUI

/// "Carnet des tenues": a private calendar of what each child wore, day after day, and what is
/// planned for today and tomorrow. Nothing leaves the iPhone.
struct OutfitJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @Query(sort: \PlannedOutfit.day) private var plans: [PlannedOutfit]
    @State private var selectedDay = Date.now

    private let calendar = Calendar.current

    var body: some View {
        let family = FamilySnapshot(children: children, garments: garments)
        let lastDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        let dayPlans = plans.filter { calendar.isDate($0.day, inSameDayAs: selectedDay) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DatePicker("Jour", selection: $selectedDay, in: ...lastDay, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                        .tint(Theme.accent)
                        .minoCard(padding: 8)

                    Text(Formatting.longDate(selectedDay))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)

                    if dayPlans.isEmpty {
                        EmptyStateView(
                            symbol: "calendar",
                            title: "Pas de tenue ce jour-là",
                            message: "Le carnet se remplit tout seul, jour après jour, avec les tenues que Mino a préparées."
                        )
                    } else {
                        ForEach(children) { child in
                            if let plan = dayPlans.first(where: { $0.child?.id == child.id }) {
                                JournalEntry(child: child, color: children.color(of: child), plan: plan, family: family)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Carnet des tenues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

private struct JournalEntry: View {
    let child: Child
    let color: Color
    let plan: PlannedOutfit
    let family: FamilySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ChildAvatar(name: child.name, color: color, size: 32)
                Text(child.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(plan.confirmedAt == nil ? "Prévue · \(plan.context.displayName)" : "Portée · \(plan.context.displayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plan.outfit.pieces, id: \.itemID) { piece in
                        GarmentImage(photo: family.garment(piece.itemID)?.photo)
                            .frame(width: 76, height: 76)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
