import MinoKit
import SwiftUI

/// One minute to sort what has become too small: swipe right to follow Mino's advice,
/// left when it still fits. Siblings and boxes come before giving away or selling.
struct SortSessionView: View {
    let garments: [Garment]
    let children: [Child]

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var decisions: [String] = []
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            Group {
                if index < garments.count {
                    card(for: garments[index])
                } else {
                    summary
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle(index < garments.count ? "Tri \(index + 1)/\(garments.count)" : "Tri terminé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: Card

    private func card(for garment: Garment) -> some View {
        let family = children.map(\.profile)
        let recommendation = LifecycleAdvisor.recommend(for: garment.item, family: family, on: .now)
        return VStack(spacing: 20) {
            VStack(spacing: 12) {
                GarmentImage(photo: garment.photo)
                    .frame(height: 260)
                Text(garment.summary)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if let owner = garment.owner {
                    Text(measurementHint(for: owner, kind: garment.category.sizeKind))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                Label("Conseil : \(DestinationLabel.text(recommendation, children: children))", systemImage: DestinationLabel.symbol(recommendation))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            .minoCard(padding: 20)
            .offset(x: dragOffset.width)
            .rotationEffect(.degrees(Double(dragOffset.width) / 25))
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation }
                    .onEnded { value in
                        if value.translation.width > 120 {
                            decide(garment, recommendation)
                        } else if value.translation.width < -120 {
                            keep(garment)
                        }
                        withAnimation(.spring) { dragOffset = .zero }
                    }
            )
            .accessibilityAction(named: "Ça va encore") { keep(garment) }
            .accessibilityAction(named: DestinationLabel.text(recommendation, children: children)) { decide(garment, recommendation) }

            Spacer()

            Button(DestinationLabel.text(recommendation, children: children)) { decide(garment, recommendation) }
                .buttonStyle(PrimaryButtonStyle())
            HStack {
                Button("Ça va encore") { keep(garment) }
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
                Menu {
                    ForEach(Array(DestinationLabel.all(for: garment, children: children).enumerated()), id: \.offset) { _, destination in
                        Button(DestinationLabel.text(destination, children: children), systemImage: DestinationLabel.symbol(destination)) {
                            decide(garment, destination)
                        }
                    }
                    Button("Garder en souvenir", systemImage: "heart.text.square") {
                        garment.move(to: .keepsake, owner: nil)
                        advance(with: "Souvenir")
                    }
                } label: {
                    Text("Autre choix")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .animation(.spring, value: index)
    }

    private func measurementHint(for child: Child, kind: SizeKind) -> String {
        let value = child.profile.measurement(for: kind, at: .now).expected
        switch kind {
        case .clothing: return "\(child.name) mesure environ \(Int(value.rounded())) cm"
        case .shoes: return "\(child.name) chausse environ du \(SizeChart.wornShoeSize(forEstimate: value))"
        }
    }

    // MARK: Summary

    private var summary: some View {
        let counts = Dictionary(grouping: decisions, by: { $0 }).mapValues(\.count)
        let ordered = decisions.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("Le dressing respire")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ordered, id: \.self) { label in
                    Text("\(label) : \(counts[label] ?? 0)")
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            if decisions.contains(DestinationLabel.text(.sell, children: children)) {
                Text("Les annonces sont prêtes dans Dressing › À vendre.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button("Terminé") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: Decisions

    private func keep(_ garment: Garment) {
        if let owner = garment.owner {
            garment.fitConfirmedAt = owner.profile.measurement(for: garment.category.sizeKind, at: .now).expected
        }
        advance(with: "Ça va encore")
    }

    private func decide(_ garment: Garment, _ destination: Destination) {
        garment.apply(destination, children: children)
        let label: String
        if case .sibling(let id, _) = destination {
            label = DestinationLabel.text(.sibling(id, fitsFrom: nil), children: children)
        } else {
            label = DestinationLabel.text(destination, children: children)
        }
        advance(with: label)
    }

    private func advance(with decision: String) {
        decisions.append(decision)
        index += 1
    }
}
