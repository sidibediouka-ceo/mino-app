import MinoKit
import SwiftData
import SwiftUI

/// The visual inventory, per child and for the family boxes.
struct WardrobeView: View {
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var scope: WardrobeScope?
    @State private var filter: FitFilter = .all
    @State private var adding = false
    @State private var sortBatch: SortBatch?

    private var currentScope: WardrobeScope {
        scope ?? children.first.map { .child($0.id) } ?? .boxes
    }

    private var currentChild: Child? {
        if case .child(let id) = currentScope { return children.first { $0.id == id } }
        return nil
    }

    var body: some View {
        let inScope = garments.filter { currentScope.contains($0) }
        let profile = currentChild?.profile
        let outgrown = profile.map { profile in inScope.filter { profile.fit(of: $0.item, on: .now) == .tooSmall } } ?? []
        let visible = inScope.filter { garment in
            guard let profile else { return true }
            return filter.accepts(profile.fit(of: garment.item, on: .now))
        }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ChipPicker(options: scopes, selection: Binding(get: { currentScope }, set: { scope = $0; filter = .all })) { option in
                        title(of: option)
                    }

                    if profile != nil {
                        ChipPicker(options: FitFilter.allCases, selection: $filter, title: \.title)
                    }

                    if !outgrown.isEmpty, let child = currentChild {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Formatting.count(outgrown.count, "vêtement trop petit", "vêtements trop petits"))
                                    .font(.headline)
                                    .foregroundStyle(Theme.forest)
                                Text("Une minute pour leur trouver une suite.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            Button("Trier") { sortBatch = SortBatch(garments: outgrown) }
                                .buttonStyle(SecondaryButtonStyle())
                                .accessibilityHint("Trier les vêtements devenus trop petits pour \(child.name)")
                        }
                        .minoCard()
                    }

                    if visible.isEmpty {
                        EmptyStateView(symbol: "hanger", title: emptyTitle, message: emptyMessage)
                    } else {
                        grid(visible, profile: profile)
                    }

                    secondLife
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Dressing")
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Ajouter des vêtements")
                        .disabled(!currentScope.acceptsNewGarments)
                }
            }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    AddGarmentsView(owner: currentChild, sizing: (currentChild ?? children.first)?.profile) { adding = false }
                        .navigationTitle(currentChild.map { "Pour \($0.name)" } ?? "Pour les cartons")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(item: $sortBatch) { batch in
                SortSessionView(garments: batch.garments, children: children)
            }
        }
    }

    private var scopes: [WardrobeScope] {
        var scopes = children.map { WardrobeScope.child($0.id) } + [.boxes]
        if garments.contains(where: { $0.state == .forSale }) { scopes.append(.forSale) }
        if garments.contains(where: { $0.state == .keepsake }) { scopes.append(.keepsakes) }
        return scopes
    }

    private func title(of scope: WardrobeScope) -> String {
        switch scope {
        case .child(let id): return children.first { $0.id == id }?.name ?? ""
        case .boxes: return "Cartons"
        case .forSale: return "À vendre"
        case .keepsakes: return "Souvenirs"
        }
    }

    private var emptyTitle: String {
        switch currentScope {
        case .child: return filter == .all ? "Le dressing est vide" : "Rien ici"
        case .boxes: return "Aucun carton"
        case .forSale: return "Rien à vendre"
        case .keepsakes: return "Aucun souvenir"
        }
    }

    private var emptyMessage: String {
        switch currentScope {
        case .child: return filter == .all ? "Touchez + pour ajouter quelques photos." : "Aucun vêtement ne correspond à ce filtre."
        case .boxes: return "Les vêtements rangés pour plus tard ou pour un plus petit apparaîtront ici."
        case .forSale: return "Mettez un vêtement en vente depuis sa fiche : l'annonce est rédigée pour vous."
        case .keepsakes: return "Les vêtements que vous gardez pour leur histoire."
        }
    }

    private func grid(_ items: [Garment], profile: ChildProfile?) -> some View {
        let groups = GarmentCategory.allCases.compactMap { category -> (GarmentCategory, [Garment])? in
            let matching = items.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
        return VStack(alignment: .leading, spacing: 20) {
            ForEach(groups, id: \.0) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(group.0.displayName) · \(group.1.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        ForEach(group.1) { garment in
                            NavigationLink(value: garment) {
                                GarmentTile(garment: garment, fit: profile?.fit(of: garment.item, on: .now))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var secondLife: some View {
        let count = garments.filter { $0.state.hasLeftFamily }.count
        if count > 0 {
            Label("\(Formatting.count(count, "vêtement a", "vêtements ont")) trouvé une seconde vie", systemImage: "leaf")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }
}

private struct GarmentTile: View {
    let garment: Garment
    let fit: Fit?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GarmentImage(photo: garment.photo)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 7)
                            .foregroundStyle(.white)
                            .background(fit == .tooSmall ? Theme.terracotta : Theme.sage, in: Capsule())
                            .padding(6)
                    }
                }
            Text(SizeChart.shortLabel(size: garment.size, kind: garment.category.sizeKind))
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([garment.summary, badge].compactMap { $0 }.joined(separator: ", "))
    }

    private var badge: String? {
        switch fit {
        case .tooSmall: return "Trop petit"
        case .roomy, .tooBig: return "Plus tard"
        default: return nil
        }
    }
}

enum WardrobeScope: Hashable {
    case child(UUID)
    case boxes
    case forSale
    case keepsakes

    func contains(_ garment: Garment) -> Bool {
        switch self {
        case .child(let id): return garment.state == .active && garment.owner?.id == id
        case .boxes: return garment.state == .stored
        case .forSale: return garment.state == .forSale
        case .keepsakes: return garment.state == .keepsake
        }
    }

    var acceptsNewGarments: Bool {
        switch self {
        case .child, .boxes: return true
        case .forSale, .keepsakes: return false
        }
    }
}

enum FitFilter: CaseIterable {
    case all, fits, outgrown, later

    var title: String {
        switch self {
        case .all: return "Tout"
        case .fits: return "À sa taille"
        case .outgrown: return "Trop petits"
        case .later: return "Pour plus tard"
        }
    }

    func accepts(_ fit: Fit) -> Bool {
        switch self {
        case .all: return true
        case .fits: return fit == .fits
        case .outgrown: return fit == .tooSmall
        case .later: return fit == .roomy || fit == .tooBig
        }
    }
}

struct SortBatch: Identifiable {
    let id = UUID()
    let garments: [Garment]
}
