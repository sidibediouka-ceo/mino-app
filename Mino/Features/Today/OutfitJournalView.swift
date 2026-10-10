import MinoKit
import SwiftData
import SwiftUI

/// "Carnet des tenues": a private calendar of what each child wore, and the place to prepare an
/// outfit ahead for a special day. On the day, the home screen shows the prepared outfit.
/// Nothing leaves the iPhone.
struct OutfitJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @Query(sort: \PlannedOutfit.day) private var plans: [PlannedOutfit]
    @State private var selectedDay = Date.now
    @State private var composing: Composition?

    private let calendar = Calendar.current

    private struct Composition: Identifiable {
        let id = UUID()
        let child: Child
        let plan: PlannedOutfit?
    }

    var body: some View {
        let family = FamilySnapshot(children: children, garments: garments)
        let today = calendar.startOfDay(for: .now)
        let lastDay = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        let isPast = calendar.startOfDay(for: selectedDay) < today
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

                    if isPast && dayPlans.isEmpty {
                        EmptyStateView(
                            symbol: "calendar",
                            title: "Pas de tenue ce jour-là",
                            message: "Le carnet se remplit tout seul, jour après jour, avec les tenues portées."
                        )
                    }

                    ForEach(children) { child in
                        let plan = dayPlans.first { $0.child?.id == child.id }
                        if let plan {
                            JournalEntry(
                                child: child, color: children.color(of: child), plan: plan, family: family,
                                isEditable: !isPast,
                                onEdit: { composing = Composition(child: child, plan: plan) },
                                onRemove: { context.delete(plan) }
                            )
                        } else if !isPast {
                            Button {
                                composing = Composition(child: child, plan: nil)
                            } label: {
                                HStack(spacing: 12) {
                                    ChildAvatar(name: child.name, color: children.color(of: child), size: 32)
                                    Text("Préparer la tenue de \(child.name)")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(children.color(of: child))
                                }
                                .minoCard(padding: 14)
                            }
                            .buttonStyle(.plain)
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
            .sheet(item: $composing) { composition in
                OutfitComposerView(child: composition.child, day: selectedDay, existing: composition.plan)
            }
        }
    }
}

private struct JournalEntry: View {
    let child: Child
    let color: Color
    let plan: PlannedOutfit
    let family: FamilySnapshot
    let isEditable: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ChildAvatar(name: child.name, color: color, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if isEditable {
                    Menu {
                        Button("Modifier la tenue", systemImage: "pencil", action: onEdit)
                        Button(role: .destructive, action: onRemove) {
                            Label(
                                plan.isPreparedByParent ? "Retirer cette tenue" : "Laisser Mino la refaire",
                                systemImage: "arrow.uturn.backward"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel("Options de la tenue de \(child.name)")
                }
            }
            if !plan.note.isEmpty {
                Label(plan.note, systemImage: "calendar.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plan.outfit.pieces, id: \.itemID) { piece in
                        GarmentImage(photo: family.garment(piece.itemID)?.photo)
                            .frame(width: 76, height: 76)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var status: String {
        let kind = plan.confirmedAt != nil ? "Portée" : (plan.isPreparedByParent ? "Préparée par vous" : "Proposée par Mino")
        return "\(kind) · \(plan.context.displayName)"
    }
}
