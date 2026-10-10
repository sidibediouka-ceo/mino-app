import MinoKit
import SwiftData
import SwiftUI

/// The visual inventory. Each child has their own dressing; the family spaces (boxes, items
/// for sale, archives) are shared and live in their own section, below.
struct WardrobeView: View {
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var selectedChildID: UUID?
    @State private var filter: FitFilter = .all
    @State private var adding = false
    @State private var sortBatch: SortBatch?

    private var child: Child? {
        children.first { $0.id == selectedChildID } ?? children.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if children.count > 1 {
                        ChildSelector(children: children, selection: Binding(
                            get: { child?.id },
                            set: { selectedChildID = $0; filter = .all }
                        ))
                    }
                    if let child {
                        childDressing(child)
                    }
                    familySpaces
                }
                .padding(20)
                .padding(.bottom, 72)
            }
            .background(Theme.background)
            .navigationTitle("Dressing")
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .navigationDestination(for: CategoryPage.self) { CategoryGarmentsView(page: $0) }
            .navigationDestination(for: WardrobeScope.self) { FamilySpaceView(scope: $0) }
            .overlay(alignment: .bottomTrailing) {
                if let child, garments.contains(where: { WardrobeScope.child(child.id).contains($0) }) {
                    AddButton { adding = true }
                }
            }
            .sheet(isPresented: $adding) {
                if let child {
                    NavigationStack {
                        AddGarmentsView(owner: child, sizing: child.profile) { adding = false }
                            .navigationTitle("Pour \(child.name)")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .sheet(item: $sortBatch) { batch in
                SortSessionView(garments: batch.garments, children: children)
            }
        }
    }

    // MARK: Child

    @ViewBuilder
    private func childDressing(_ child: Child) -> some View {
        let scope = WardrobeScope.child(child.id)
        let profile = child.profile
        let outgrown = garments.filter { scope.contains($0) && profile.fit(of: $0.item, on: .now) == .tooSmall }
        let visible = scope.visible(garments, profile: profile, filter: filter)

        ChipPicker(options: FitFilter.allCases, selection: $filter, title: \.title)

        if !outgrown.isEmpty {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatting.count(outgrown.count, "vêtement devenu petit", "vêtements devenus petits"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Une minute pour leur trouver une suite.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button("Trier") { sortBatch = SortBatch(garments: outgrown) }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityHint("Trier les vêtements devenus petits pour \(child.name)")
            }
            .minoCard()
        }

        if visible.isEmpty {
            EmptyStateView(
                symbol: "hanger",
                title: filter == .all ? "Le dressing de \(child.name) est vide" : "Rien ici",
                message: filter == .all ? "Quelques photos suffisent pour commencer." : "Aucun vêtement ne correspond à ce filtre."
            ) {
                if filter == .all {
                    Button("Ajouter des vêtements", systemImage: "camera.fill") { adding = true }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Voir tout le dressing") { filter = .all }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        } else {
            WardrobeSections(garments: visible, profile: profile, scope: scope, filter: filter)
        }
    }

    // MARK: Family

    private var familySpaces: some View {
        let boxes = garments.filter { WardrobeScope.boxes.contains($0) }.count
        let forSale = garments.filter { WardrobeScope.forSale.contains($0) }.count
        let archived = garments.filter { WardrobeScope.archive.contains($0) }.count
        let secondLife = garments.filter { $0.state.hasLeftFamily }.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("Pour toute la famille")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            FamilySpaceRow(
                scope: .boxes, symbol: "shippingbox.fill", count: boxes,
                subtitle: "Pour plus tard ou pour les plus jeunes"
            )
            if forSale > 0 {
                FamilySpaceRow(scope: .forSale, symbol: "tag.fill", count: forSale, subtitle: "Annonces prêtes à partager")
            }
            if archived > 0 {
                FamilySpaceRow(
                    scope: .archive, symbol: "leaf.fill", count: archived,
                    subtitle: secondLife > 0
                        ? "\(Formatting.count(secondLife, "vêtement a", "vêtements ont")) trouvé une seconde vie"
                        : "Souvenirs gardés"
                )
            }
        }
    }
}

/// A child picker with each child's avatar and colour.
private struct ChildSelector: View {
    let children: [Child]
    @Binding var selection: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(children) { child in
                    let isSelected = child.id == selection
                    let color = children.color(of: child)
                    Button { selection = child.id } label: {
                        HStack(spacing: 8) {
                            ChildAvatar(name: child.name, color: color, size: 30)
                            Text(child.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.vertical, 6)
                        .padding(.leading, 6)
                        .padding(.trailing, 14)
                        .background(isSelected ? color.opacity(0.22) : Theme.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(isSelected ? color : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(2)
        }
    }
}

private struct FamilySpaceRow: View {
    let scope: WardrobeScope
    let symbol: String
    let count: Int
    let subtitle: String

    var body: some View {
        NavigationLink(value: scope) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Theme.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(scope.title) · \(count)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
            }
            .minoCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

/// A shared family space: boxes, items for sale or archives.
private struct FamilySpaceView: View {
    let scope: WardrobeScope

    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var adding = false

    var body: some View {
        let items = scope.visible(garments, profile: nil, filter: .all)
        ScrollView {
            Group {
                if items.isEmpty {
                    EmptyStateView(symbol: "shippingbox", title: "Rien pour l'instant", message: scope.emptyMessage) {
                        if scope.acceptsNewGarments {
                            Button("Ajouter aux cartons", systemImage: "camera.fill") { adding = true }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                } else {
                    WardrobeSections(garments: items, profile: nil, scope: scope, filter: .all)
                }
            }
            .padding(20)
            .padding(.bottom, 72)
        }
        .background(Theme.background)
        .navigationTitle(scope.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            if scope.acceptsNewGarments && !items.isEmpty {
                AddButton { adding = true }
            }
        }
        .sheet(isPresented: $adding) {
            NavigationStack {
                AddGarmentsView(owner: nil, sizing: children.first?.profile) { adding = false }
                    .navigationTitle("Pour les cartons")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

/// Garments grouped by category. Three per category keep every category within reach;
/// "Voir tout" opens the rest.
private struct WardrobeSections: View {
    let garments: [Garment]
    let profile: ChildProfile?
    let scope: WardrobeScope
    let filter: FitFilter

    private static let previewCount = 3

    var body: some View {
        let groups = GarmentCategory.allCases.compactMap { category -> (GarmentCategory, [Garment])? in
            let matching = garments.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groups, id: \.0) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(group.0.displayName) · \(group.1.count)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if group.1.count > Self.previewCount {
                            NavigationLink(value: CategoryPage(category: group.0, scope: scope, filter: filter)) {
                                HStack(spacing: 2) {
                                    Text("Voir tout")
                                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                                }
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    GarmentGrid(garments: Array(group.1.prefix(Self.previewCount)), profile: profile)
                }
            }
        }
    }
}

/// Every garment of one category, opened from "Voir tout".
private struct CategoryGarmentsView: View {
    let page: CategoryPage

    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]

    var body: some View {
        let profile = page.scope.child(in: children)?.profile
        let items = page.scope.visible(garments, profile: profile, filter: page.filter).filter { $0.category == page.category }
        ScrollView {
            GarmentGrid(garments: items, profile: profile)
                .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("\(page.category.displayName) · \(items.count)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Three columns of garment tiles, each opening its detail.
private struct GarmentGrid: View {
    let garments: [Garment]
    let profile: ChildProfile?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
            ForEach(garments) { garment in
                NavigationLink(value: garment) {
                    GarmentTile(garment: garment, fit: profile?.fit(of: garment.item, on: .now))
                }
                .buttonStyle(.plain)
            }
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
                            .background(Theme.ink.opacity(0.7), in: Capsule())
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
        switch garment.state {
        case .donated: return "Donné"
        case .sold: return "Vendu"
        case .keepsake: return "Souvenir"
        default: break
        }
        switch fit {
        case .tooSmall: return "Devenu petit"
        case .roomy, .tooBig: return "Plus tard"
        default: return nil
        }
    }
}

/// The floating "Ajouter" button.
private struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Ajouter", systemImage: "plus")
                .font(.system(.headline, design: .rounded))
                .padding(.vertical, 14)
                .padding(.horizontal, 22)
                .foregroundStyle(Theme.onAccent)
                .background(Theme.accent, in: Capsule())
                .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 6)
        }
        .padding(20)
        .accessibilityLabel("Ajouter des vêtements")
    }
}

enum WardrobeScope: Hashable {
    case child(UUID)
    case boxes
    case forSale
    /// Donated, sold and keepsakes: nothing is ever lost.
    case archive

    var title: String {
        switch self {
        case .child: return "Dressing"
        case .boxes: return "Cartons"
        case .forSale: return "À vendre"
        case .archive: return "Archives"
        }
    }

    var emptyMessage: String {
        switch self {
        case .child: return "Quelques photos suffisent pour commencer."
        case .boxes: return "Les vêtements rangés pour plus tard ou pour un plus petit apparaîtront ici."
        case .forSale: return "Mettez un vêtement en vente depuis sa fiche : l'annonce est rédigée pour vous."
        case .archive: return "Les vêtements donnés, vendus ou gardés en souvenir restent consultables ici."
        }
    }

    func contains(_ garment: Garment) -> Bool {
        switch self {
        case .child(let id): return garment.state == .active && garment.owner?.id == id
        case .boxes: return garment.state == .stored
        case .forSale: return garment.state == .forSale
        case .archive: return garment.state.hasLeftFamily || garment.state == .keepsake
        }
    }

    func child(in children: [Child]) -> Child? {
        if case .child(let id) = self { return children.first { $0.id == id } }
        return nil
    }

    /// The garments shown for this scope; for a child, narrowed by how they fit.
    func visible(_ garments: [Garment], profile: ChildProfile?, filter: FitFilter) -> [Garment] {
        garments.filter { garment in
            guard contains(garment) else { return false }
            guard let profile else { return true }
            return filter.accepts(profile.fit(of: garment.item, on: .now))
        }
    }

    var acceptsNewGarments: Bool {
        self == .boxes
    }
}

enum FitFilter: CaseIterable {
    case all, fits, outgrown, later

    var title: String {
        switch self {
        case .all: return "Tout"
        case .fits: return "À sa taille"
        case .outgrown: return "Devenus petits"
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

/// Navigation value for a category's full list.
struct CategoryPage: Hashable {
    let category: GarmentCategory
    let scope: WardrobeScope
    let filter: FitFilter
}

struct SortBatch: Identifiable {
    let id = UUID()
    let garments: [Garment]
}
