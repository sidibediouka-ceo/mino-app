import MinoKit
import SwiftUI

/// A child's outfit laid out like a flat-lay on their own colour. Tapping a piece offers the
/// next best alternative; the main action hands the outfit over to the child.
struct OutfitCard: View {
    let child: Child
    let color: Color
    let plan: PlannedOutfit
    let family: FamilySnapshot
    let onSwap: (OutfitSlot) -> Void
    let onContext: (DayContext) -> Void
    let onDressing: () -> Void
    let onGaps: () -> Void

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
                Text("Rien dans le dressing ne convient à ce temps-là pour l'instant.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
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
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
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
                            "Rien à sa taille pour : \(outfit.gaps.map { $0.displayName.lowercased() }.joined(separator: ", "))",
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
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
                    Text("Touchez un vêtement pour en voir un autre.")
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

    private var contextMenu: some View {
        Menu {
            ForEach(DayContext.allCases, id: \.self) { option in
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
