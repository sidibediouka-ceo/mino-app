import MinoKit
import SwiftData
import SwiftUI

/// Everything about one garment, and its next life one tap away.
struct GarmentDetailView: View {
    @Bindable var garment: Garment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Child.createdAt) private var children: [Child]
    @State private var confirmingDeletion = false
    @State private var lastChange: LifecycleChange?

    /// What a lifecycle action replaced, so the confirmation can offer to undo it.
    private struct LifecycleChange {
        let id = UUID()
        let message: String
        let state: LifecycleState
        let owner: Child?
        let lastOwnerID: UUID?
        let fitConfirmedAt: Double?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GarmentImage(photo: garment.photo)
                    .frame(height: 260)

                status

                GarmentFields(
                    category: $garment.category, color: $garment.color, size: $garment.size,
                    occasion: $garment.occasion, brand: $garment.brand, suggested: [], sizing: garment.owner?.profile
                )
                .minoCard()

                lifecycle

                Button("Supprimer ce vêtement", role: .destructive) { confirmingDeletion = true }
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(garment.category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { confirmation }
        .sensoryFeedback(.success, trigger: lastChange?.id)
        .confirmationDialog("Supprimer ce vêtement ?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                context.delete(garment)
                dismiss()
            }
        } message: {
            Text("Pour un vêtement donné ou vendu, préférez la seconde vie : Mino garde la trace de ce qui a circulé.")
        }
    }

    // MARK: Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusTitle)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            if garment.wearCount > 0, let lastWornAt = garment.lastWornAt {
                Text("Porté \(Formatting.count(garment.wearCount, "fois", "fois")), dernièrement le \(Formatting.shortDate(lastWornAt))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var statusTitle: String {
        switch garment.state {
        case .active:
            guard let owner = garment.owner else { return "Dans le dressing" }
            let profile = owner.profile
            switch profile.fit(of: garment.item, on: .now) {
            case .fits: return "Va bien à \(owner.name)"
            case .tooSmall: return "Devenu petit pour \(owner.name)"
            case .roomy, .tooBig:
                guard let date = profile.dateItemFits(garment.item, from: .now) else { return "Encore grand pour \(owner.name)" }
                return "À la taille de \(owner.name) \(Formatting.window(date))"
            }
        case .stored: return "Dans les cartons de la famille"
        case .forSale: return "En vente"
        case .donated: return "Donné"
        case .sold: return "Vendu"
        case .keepsake: return "Gardé en souvenir"
        }
    }

    // MARK: Lifecycle

    private var lifecycle: some View {
        let family = children.map(\.profile)
        let isOutgrown = garment.state == .active
            && garment.owner.map { $0.profile.fit(of: garment.item, on: .now) == .tooSmall } == true
        let recommendation = isOutgrown || garment.state == .stored
            ? LifecycleAdvisor.recommend(for: garment.item, family: family, on: .now)
            : nil

        return VStack(alignment: .leading, spacing: 12) {
            Text("Sa prochaine vie")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            if let recommendation {
                Button { apply(recommendation) } label: {
                    Label("Conseil : \(DestinationLabel.text(recommendation, children: children))", systemImage: DestinationLabel.symbol(recommendation))
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if garment.state == .forSale {
                let listing = ListingWriter.listing(for: garment.item, brand: garment.brand)
                ShareLink(item: listing.text, subject: Text(listing.title)) {
                    Label("Partager l'annonce", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Vendu", systemImage: "checkmark.seal") {
                    change("Vendu ! Il reste visible dans les Archives.") { garment.move(to: .sold, owner: nil) }
                }
                    .buttonStyle(SecondaryButtonStyle())
            }

            ActionList(actions: actions)
        }
        .minoCard()
    }

    private var actions: [(title: String, symbol: String, perform: () -> Void)] {
        var actions: [(title: String, symbol: String, perform: () -> Void)] = []
        for destination in DestinationLabel.all(for: garment, children: children) {
            if destination == .sell && garment.state == .forSale { continue }
            if destination == .store && garment.state == .stored { continue }
            actions.append((DestinationLabel.text(destination, children: children), DestinationLabel.symbol(destination), {
                apply(destination)
            }))
        }
        if garment.state != .keepsake {
            actions.append(("Garder en souvenir", "heart.text.square", {
                change("Gardé en souvenir. Il reste visible dans les Archives.") { garment.move(to: .keepsake, owner: nil) }
            }))
        }
        return actions
    }

    // MARK: Confirmation

    private func apply(_ destination: Destination) {
        let message: String
        switch destination {
        case .sibling(let id, _):
            message = "C'est fait : il est dans le dressing de \(children.first { $0.id == id }?.name ?? "")."
        case .store: message = "Rangé dans les cartons de la famille."
        case .donate: message = "Merci pour ce don ! Il reste visible dans les Archives."
        case .sell: message = "En vente : l'annonce est prête à partager."
        }
        change(message) { garment.apply(destination, children: children) }
    }

    private func change(_ message: String, _ perform: () -> Void) {
        let previous = LifecycleChange(
            message: message, state: garment.state, owner: garment.owner,
            lastOwnerID: garment.lastOwnerID, fitConfirmedAt: garment.fitConfirmedAt
        )
        perform()
        withAnimation(.snappy) { lastChange = previous }
    }

    private func undo(_ change: LifecycleChange) {
        garment.move(to: change.state, owner: change.owner)
        garment.lastOwnerID = change.lastOwnerID
        garment.fitConfirmedAt = change.fitConfirmedAt
        withAnimation(.snappy) { lastChange = nil }
    }

    @ViewBuilder
    private var confirmation: some View {
        if let lastChange {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                Text(lastChange.message)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Annuler") { undo(lastChange) }
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Theme.background)
            .padding(16)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: lastChange.id) {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.snappy) { self.lastChange = nil }
            }
        }
    }
}

/// Secondary actions, one capsule per line.
private struct ActionList: View {
    let actions: [(title: String, symbol: String, perform: () -> Void)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(actions.indices, id: \.self) { index in
                Button(actions[index].title, systemImage: actions[index].symbol, action: actions[index].perform)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}
