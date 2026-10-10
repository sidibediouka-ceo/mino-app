import MinoKit
import SwiftUI

/// A child's outfit for the day. Tapping a piece offers the next best alternative.
struct OutfitCard: View {
    let child: Child
    let plan: PlannedOutfit
    let family: FamilySnapshot
    let onSwap: (OutfitSlot) -> Void
    let onContext: (DayContext) -> Void
    let onConfirm: () -> Void
    let onDressing: () -> Void
    let onGaps: () -> Void

    private var isConfirmed: Bool { plan.confirmedAt != nil }

    var body: some View {
        let outfit = plan.outfit
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ChildAvatar(name: child.name)
                Text(child.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.forest)
                Spacer()
                contextMenu
            }

            if outfit.pieces.isEmpty {
                Text("Rien dans le dressing ne convient à ce temps-là pour l'instant.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(outfit.pieces, id: \.itemID) { piece in
                            if let garment = family.garment(piece.itemID) {
                                Button { onSwap(piece.slot) } label: {
                                    VStack(spacing: 6) {
                                        GarmentImage(photo: garment.photo)
                                            .frame(width: 92, height: 92)
                                        Text(piece.slot.displayName)
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isConfirmed)
                                .accessibilityLabel(garment.summary)
                                .accessibilityHint("Touchez pour proposer autre chose")
                            }
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: plan.piecesRaw)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(outfit.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "leaf")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if !outfit.gaps.isEmpty {
                Button(action: onGaps) {
                    Label(
                        "Rien à sa taille pour : \(outfit.gaps.map { $0.displayName.lowercased() }.joined(separator: ", "))",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button(action: onDressing) {
                    Label("Mode enfant", systemImage: "face.smiling")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(outfit.pieces.isEmpty)
                Button(action: onConfirm) {
                    Label(isConfirmed ? "Habillé" : "C'est porté", systemImage: isConfirmed ? "checkmark.circle.fill" : "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isConfirmed || outfit.pieces.isEmpty)
            }
        }
        .minoCard()
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
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .foregroundStyle(Theme.forest)
            .background(Theme.sage.opacity(0.22), in: Capsule())
        }
        .disabled(isConfirmed)
        .accessibilityLabel("Type de journée : \(plan.context.displayName)")
    }
}
