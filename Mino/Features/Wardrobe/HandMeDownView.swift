import MinoKit
import SwiftData
import SwiftUI

/// "Le dressing familial vivant": the clothes a child can take over from the family boxes or
/// from an older sibling, without buying anything. Pick them, they join the child's dressing.
struct HandMeDownView: View {
    let child: Child

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @State private var selection: Set<UUID> = []

    var body: some View {
        let available = FamilySnapshot(children: children, garments: garments).availableGarments(for: child)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ces vêtements de la famille vont à \(child.name) en ce moment. Touchez ceux à lui confier.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                        ForEach(available) { garment in
                            let isSelected = selection.contains(garment.id)
                            Button { toggle(garment.id) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    GarmentImage(photo: garment.photo)
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryText)
                                                .background(Circle().fill(Theme.card))
                                                .padding(6)
                                        }
                                    Text(origin(of: garment))
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(garment.summary), \(origin(of: garment))")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("De la famille")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selection.count == available.count ? "Aucun" : "Tous") {
                        selection = selection.count == available.count ? [] : Set(available.map(\.id))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Confier \(Formatting.count(selection.count, "vêtement", "vêtements")) à \(child.name)") {
                    for garment in available where selection.contains(garment.id) {
                        garment.move(to: .active, owner: child)
                    }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(color: children.color(of: child)))
                .disabled(selection.isEmpty)
                .padding(20)
                .background(.bar)
            }
        }
    }

    private func origin(of garment: Garment) -> String {
        if let owner = garment.owner { return "De \(owner.name)" }
        if let name = children.first(where: { $0.id == garment.lastOwnerID })?.name { return "Cartons · de \(name)" }
        return "Cartons"
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
}
