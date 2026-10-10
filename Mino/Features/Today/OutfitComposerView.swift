import MinoKit
import SwiftData
import SwiftUI

/// Prepares a child's outfit for a given day, ahead of time ("je sais déjà ce qu'il portera
/// à la soirée"). Mino pre-fills a proposal; the parent picks what they want. On the day,
/// the home screen shows exactly this outfit.
struct OutfitComposerView: View {
    let child: Child
    let day: Date
    /// The plan being edited, if the day already has one.
    let existing: PlannedOutfit?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(WeatherStore.self) private var weather
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @State private var dayContext: DayContext = .outing
    @State private var note = ""
    @State private var selection: [OutfitPiece] = []

    private let calendar = Calendar.current

    var body: some View {
        let family = FamilySnapshot(children: children, garments: garments)
        let color = children.color(of: child)
        let wearable = wearableGarments(in: family)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !selection.isEmpty {
                        OutfitBoard(pieces: selection, family: family)
                            .padding(16)
                            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .animation(.snappy, value: selection)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pour quoi ? (facultatif)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        TextField("Ex. Soirée chez Lina", text: $note)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type de journée")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        ChipPicker(options: DayContext.allCases, selection: $dayContext, title: \.displayName)
                    }
                    Button("Laisser Mino proposer", systemImage: "sparkles") { suggest(in: family) }
                        .buttonStyle(SecondaryButtonStyle())

                    if wearable.isEmpty {
                        EmptyStateView(
                            symbol: "hanger", title: "Rien à sa taille ce jour-là",
                            message: "Ajoutez des vêtements à son dressing pour préparer cette tenue."
                        )
                    } else {
                        ForEach(GarmentCategory.allCases.filter { category in wearable.contains { $0.category == category } }, id: \.self) { category in
                            CategoryPicker(
                                category: category,
                                garments: wearable.filter { $0.category == category },
                                selected: Set(selection.map(\.itemID)),
                                color: color
                            ) { toggle($0) }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("\(child.name) · \(Formatting.shortDate(day))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Enregistrer la tenue", action: save)
                    .buttonStyle(PrimaryButtonStyle(color: color))
                    .disabled(selection.isEmpty)
                    .padding(20)
                    .background(.bar)
            }
            .onAppear { load(in: family) }
        }
    }

    /// The child's garments that will fit on that day.
    private func wearableGarments(in family: FamilySnapshot) -> [Garment] {
        guard let profile = family.profile(child.id) else { return [] }
        return garments.filter { garment in
            garment.owner?.id == child.id && garment.state == .active && garment.category.slot != nil
                && profile.fit(of: garment.item, on: day).isWearable
        }
    }

    private func load(in family: FamilySnapshot) {
        guard let existing else {
            dayContext = child.routine.context(on: day, calendar: calendar)
            suggest(in: family)
            return
        }
        dayContext = existing.context
        note = existing.note
        selection = existing.outfit.pieces
    }

    private func suggest(in family: FamilySnapshot) {
        guard let profile = family.profile(child.id) else { return }
        let outfit = OutfitEngine(calendar: calendar).propose(
            child: profile, items: family.items, weather: weather.forecast(for: day), context: dayContext
        )
        selection = outfit.pieces
    }

    /// Layers stack (a pull and a gilet, several accessories); every other slot holds one garment.
    /// Nothing else is exclusive: a t-shirt under a dress or a salopette, leggings under a dress,
    /// the parent decides.
    private func toggle(_ garment: Garment) {
        guard let slot = garment.category.slot else { return }
        if selection.contains(where: { $0.itemID == garment.id }) {
            selection.removeAll { $0.itemID == garment.id }
            return
        }
        if slot != .layer && slot != .accessory {
            selection.removeAll { $0.slot == slot }
        }
        selection.append(OutfitPiece(slot: slot, itemID: garment.id))
    }

    private func save() {
        let plan: PlannedOutfit
        if let existing {
            plan = existing
        } else {
            plan = PlannedOutfit(day: calendar.startOfDay(for: day))
            context.insert(plan)
            plan.child = child
        }
        plan.context = dayContext
        plan.note = note.trimmingCharacters(in: .whitespaces)
        plan.outfit = Outfit(pieces: selection, gaps: [], reasons: [])
        plan.proposedRaw = []
        plan.skippedIDs = []
        plan.confirmedAt = nil
        dismiss()
    }
}

private struct CategoryPicker: View {
    let category: GarmentCategory
    let garments: [Garment]
    let selected: Set<UUID>
    let color: Color
    let onToggle: (Garment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.displayName)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(garments) { garment in
                        let isSelected = selected.contains(garment.id)
                        Button { onToggle(garment) } label: {
                            GarmentImage(photo: garment.photo)
                                .frame(width: 88, height: 88)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(isSelected ? color : .clear, lineWidth: 3)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(color)
                                            .background(Circle().fill(Theme.card))
                                            .padding(5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(garment.summary)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
    }
}
