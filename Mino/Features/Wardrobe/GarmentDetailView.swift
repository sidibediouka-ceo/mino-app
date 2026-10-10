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
    @State private var sharing: ListingShare?

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
        .sheet(item: $sharing) { ShareSheet(share: $0) }
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

    /// Mino's advice first, then the family (children, boxes, keepsakes), then a second life
    /// elsewhere (give, sell): three clear groups rather than one long list.
    private var lifecycle: some View {
        let family = children.map(\.profile)
        let isOutgrown = garment.state == .active
            && garment.owner.map { $0.profile.fit(of: garment.item, on: .now) == .tooSmall } == true
        let recommendation = isOutgrown || garment.state == .stored
            ? LifecycleAdvisor.recommend(for: garment.item, family: family, on: .now)
            : nil
        let recipients = DestinationLabel.recipients(for: garment, children: children)

        return VStack(alignment: .leading, spacing: 18) {
            Text("Sa prochaine vie")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)

            if let recommendation {
                Button { apply(recommendation) } label: {
                    Label("Conseil : \(DestinationLabel.text(recommendation, children: children))", systemImage: DestinationLabel.symbol(recommendation))
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if garment.state == .forSale {
                saleListing
            }

            group("Dans la famille") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recipients) { child in
                            DestinationTile(title: child.name, hint: fitHint(for: child)) {
                                ChildAvatar(name: child.name, color: children.color(of: child), size: 44)
                            } action: {
                                apply(.sibling(child.id, fitsFrom: nil))
                            }
                        }
                        if garment.state != .stored {
                            DestinationTile(title: "Aux cartons", hint: "Pour plus tard") {
                                tileIcon("shippingbox.fill")
                            } action: {
                                apply(.store)
                            }
                        }
                        if garment.state != .keepsake {
                            DestinationTile(title: "En souvenir", hint: "On le garde") {
                                tileIcon("heart.text.square.fill")
                            } action: {
                                change("Gardé en souvenir. Il reste visible dans les Archives.") { garment.move(to: .keepsake, owner: nil) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }

            if !garment.state.hasLeftFamily {
                group("Une seconde vie ailleurs") {
                    HStack(spacing: 10) {
                        DestinationTile(title: "Donner", hint: "Association, proches") {
                            tileIcon("heart.fill")
                        } action: {
                            apply(.donate)
                        }
                        if garment.state != .forSale {
                            DestinationTile(title: "Vendre", hint: "Annonce rédigée") {
                                tileIcon("tag.fill")
                            } action: {
                                apply(.sell)
                            }
                        }
                    }
                }
            }
        }
        .minoCard()
    }

    /// Everything needed to publish on any resale app in under a minute.
    private var saleListing: some View {
        let listing = ListingWriter.listing(for: garment.item, brand: garment.brand)
        return VStack(alignment: .leading, spacing: 12) {
            group("État du vêtement") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Condition.allCases, id: \.self) { condition in
                            Chip(title: condition.displayName, isSelected: garment.condition == condition) {
                                garment.condition = condition
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            Button {
                sharing = ListingShare(text: listing.text, photos: [garment.photo])
            } label: {
                Label("Partager la photo et l'annonce", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            HStack(spacing: 10) {
                CopyButton(title: "Copier le titre", text: listing.title)
                CopyButton(title: "Copier le texte", text: listing.description)
            }
            Text("Dans l'app de revente : ajoutez la photo, collez le titre et le texte, fixez votre prix.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            Button("C'est vendu", systemImage: "checkmark.seal") {
                change("Vendu ! Il reste visible dans les Archives.") { garment.move(to: .sold, owner: nil) }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(14)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    private func tileIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(Theme.accent)
            .frame(width: 44, height: 44)
            .background(Theme.chip, in: Circle())
    }

    /// Would it fit this child? Said in a few words under their avatar.
    private func fitHint(for child: Child) -> String {
        let profile = child.profile
        switch profile.fit(of: garment.item, on: .now) {
        case .fits: return "À sa taille"
        case .roomy: return "Un peu grand"
        case .tooSmall: return "Déjà petit"
        case .tooBig:
            return profile.dateItemFits(garment.item, from: .now).map { "Vers \(Formatting.period($0.expected))" } ?? "Plus tard"
        }
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

/// One possible destination: an avatar or icon, a name, and a short hint.
private struct DestinationTile<Icon: View>: View {
    let title: String
    let hint: String
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(minWidth: 96, maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(hint)
    }
}
