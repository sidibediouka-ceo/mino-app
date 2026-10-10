import MinoKit
import SwiftUI

/// A child's outfit laid out like a flat-lay on their own colour. Tapping a piece offers the
/// next best alternative; the main action hands the outfit over to the child.
struct OutfitCard: View {
    let child: Child
    let color: Color
    let plan: PlannedOutfit
    let family: FamilySnapshot
    /// Family garments that would fit this child today (boxes, outgrown by a sibling).
    let availableFromFamily: Int
    let onSwap: (OutfitSlot) -> Void
    let onContext: (DayContext) -> Void
    let onDressing: () -> Void
    let onGaps: () -> Void
    let onAddGarments: () -> Void
    let onTakeFromFamily: () -> Void

    private var isDone: Bool { plan.confirmedAt != nil }

    var body: some View {
        let outfit = plan.outfit
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ChildAvatar(name: child.name, color: color, size: 42)
                Text(child.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                contextMenu
            }

            if outfit.pieces.isEmpty {
                emptyWardrobe
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(outfit.pieces, id: \.itemID) { piece in
                            if let garment = family.garment(piece.itemID) {
                                Button { onSwap(piece.slot) } label: {
                                    VStack(spacing: 6) {
                                        GarmentImage(photo: garment.photo)
                                            .frame(width: 118, height: 118)
                                        Text(piece.slot.displayName)
                                            .font(.system(.caption, design: .rounded).weight(.medium))
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isDone)
                                .accessibilityLabel(garment.summary)
                                .accessibilityHint("Touchez pour proposer autre chose")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                }
                .sensoryFeedback(.selection, trigger: plan.piecesRaw)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(outfit.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "sparkle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                if !outfit.gaps.isEmpty {
                    Button(action: onGaps) {
                        Label(
                            "Pas encore à sa taille : \(outfit.gaps.map { $0.displayName.lowercased() }.joined(separator: ", ")). Mino vous aide à anticiper.",
                            systemImage: "lightbulb"
                        )
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isDone {
                Label("C'est fait, bonne journée !", systemImage: "checkmark.circle.fill")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(color)
            } else if !outfit.pieces.isEmpty {
                VStack(spacing: 6) {
                    Button(action: onDressing) {
                        Label("Habiller \(child.name)", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: color))
                    Text("Toucher un vêtement pour voir d'autres options.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .sensoryFeedback(.success, trigger: plan.confirmedAt)
    }

    /// A new child, or nothing suited to the weather yet: two ways forward, never a dead end.
    private var emptyWardrobe: some View {
        let hasGarments = family.items.contains { $0.ownerID == child.id && $0.state == .active }
        return VStack(alignment: .leading, spacing: 10) {
            Text(hasGarments
                 ? "Rien dans son dressing ne convient encore à ce temps-là."
                 : "Le dressing de \(child.name) attend ses premiers vêtements.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Button("Ajouter ses vêtements", systemImage: "camera.fill", action: onAddGarments)
                .buttonStyle(PrimaryButtonStyle(color: color))
            if availableFromFamily > 0 {
                Button(
                    "Reprendre \(Formatting.count(availableFromFamily, "vêtement", "vêtements")) de la famille",
                    systemImage: "arrow.triangle.2.circlepath",
                    action: onTakeFromFamily
                )
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    /// Sport and Fête appear once some of the child's garments are tagged for them.
    private var offeredContexts: [DayContext] {
        let occasions = Set(family.items.filter { $0.ownerID == child.id && $0.state == .active }.map(\.occasion))
        return DayContext.offered(for: occasions, current: plan.context)
    }

    private var contextMenu: some View {
        Menu {
            ForEach(offeredContexts, id: \.self) { option in
                Button { onContext(option) } label: {
                    if option == plan.context {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(plan.context.displayName)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .padding(.vertical, 7)
            .padding(.horizontal, 13)
            .foregroundStyle(Theme.ink)
            .background(Theme.card, in: Capsule())
        }
        .disabled(isDone)
        .accessibilityLabel("Type de journée : \(plan.context.displayName)")
    }
}
