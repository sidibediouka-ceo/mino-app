import Charts
import MinoKit
import SwiftData
import SwiftUI

/// "La taille d'après": what to do now, where the child is heading, and what the wardrobe will
/// need, family boxes first. Everything that asks for a gesture outside the daily outfit lives here.
struct GrowthView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @State private var selectedID: UUID?
    @State private var measuring: Child?
    @State private var adding: Child?
    @State private var editing: Child?
    @State private var sortBatch: SortBatch?

    private var selected: Child? {
        children.first { $0.id == selectedID } ?? children.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if children.count > 1, let selected {
                        ChipPicker(options: children.map(\.id), selection: Binding(get: { selected.id }, set: { selectedID = $0 })) { id in
                            children.first { $0.id == id }?.name ?? ""
                        }
                    }
                    if let child = selected {
                        let family = FamilySnapshot(children: children, garments: garments)
                        let needs = family.needs(on: .now, calendar: .current).filter { $0.childID == child.id }
                        let color = children.color(of: child)
                        toDo(for: child, family: family, needs: needs)
                        outlook(for: child, color: color)
                        upcoming(for: child, family: family, needs: needs)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Grandir")
            .toolbar {
                if let selected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Modifier") { editing = selected }
                            .accessibilityLabel("Modifier le profil de \(selected.name)")
                    }
                }
            }
            .sheet(item: $editing) { child in
                NavigationStack {
                    ChildFormView(mode: .edit(child)) { _ in editing = nil }
                        .navigationTitle(child.name)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(item: $measuring) { MeasureView(child: $0) }
            .sheet(item: $sortBatch) { SortSessionView(garments: $0.garments, children: children) }
            .sheet(item: $adding) { child in
                NavigationStack {
                    AddGarmentsView(owner: child, sizing: child.profile) { adding = nil }
                        .navigationTitle("Pour \(child.name)")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .onChange(of: router.focusedChildID, initial: true) { _, id in
                if let id { selectedID = id }
            }
        }
    }

    // MARK: To do

    @ViewBuilder
    private func toDo(for child: Child, family: FamilySnapshot, needs: [Need]) -> some View {
        let items = Briefing.compose(family: family.profiles, items: family.items, needs: needs, on: .now)
            .filter { $0.childID == child.id }
        if !items.isEmpty {
            sectionTitle("À faire")
            ForEach(items) { item in
                BriefingCard(content: content(for: item, child: child)) {
                    perform(item, child: child, family: family)
                }
            }
        }
    }

    private func content(for item: BriefingItem, child: Child) -> BriefingContent {
        switch item {
        case .sort(_, let itemIDs):
            return BriefingContent(
                symbol: "arrow.triangle.2.circlepath",
                title: Formatting.count(itemIDs.count, "vêtement devenu petit", "vêtements devenus petits"),
                message: "Une minute pour leur trouver une suite : frère ou sœur, cartons, don ou vente.",
                action: "Trier"
            )
        case .retrieve(let need):
            let size = SizeChart.shortLabel(size: need.size, kind: need.group.sizeKind)
            return BriefingContent(
                symbol: "shippingbox.fill", title: "Déjà dans vos cartons",
                message: "\(need.group.displayName) : \(Formatting.count(need.familyStock.count, "pièce", "pièces")) en \(size) pour \(need.season.displayName). Inutile d'acheter.",
                action: "Récupérer"
            )
        case .measure:
            return BriefingContent(
                symbol: "ruler.fill", title: "Mesurer \(child.name)",
                message: "Trente secondes pour des prévisions de taille plus justes.", action: "Mesurer"
            )
        }
    }

    private func perform(_ item: BriefingItem, child: Child, family: FamilySnapshot) {
        switch item {
        case .sort(_, let itemIDs):
            sortBatch = SortBatch(garments: itemIDs.compactMap(family.garment))
        case .retrieve(let need):
            for id in need.familyStock {
                family.garment(id)?.move(to: .active, owner: child)
            }
        case .measure:
            measuring = child
        }
    }

    // MARK: Outlook

    private func outlook(for child: Child, color: Color) -> some View {
        let now = Date.now
        let profile = child.profile
        let clothing = profile.currentSize(.clothing, on: now)
        let shoes = profile.currentSize(.shoes, on: now)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SizeBadge(value: SizeChart.shortLabel(size: clothing, kind: .clothing), caption: "\(clothing) cm", color: color)
                SizeBadge(value: "\(shoes)", caption: "pointure", color: color)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let next = profile.nextSize(.clothing, after: now) {
                    Label("Passe en \(SizeChart.shortLabel(size: next.size, kind: .clothing)) \(Formatting.window(next.when))", systemImage: "arrow.up.right")
                }
                if let next = profile.nextSize(.shoes, after: now) {
                    Label("Pointure \(next.size) \(Formatting.window(next.when))", systemImage: "shoeprints.fill")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.ink)

            GrowthChart(profile: profile, color: color)

            Text(precisionNote(for: profile))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)

            Button("Nouvelle mesure", systemImage: "ruler") { measuring = child }
                .buttonStyle(SecondaryButtonStyle())
        }
        .minoCard()
    }

    private func precisionNote(for profile: ChildProfile) -> String {
        guard let measured = profile.lastMeasuredHeightDate else {
            return "Estimation d'après la taille de ses vêtements et les courbes de l'OMS. Une mesure rendra les prévisions plus justes."
        }
        return "D'après la mesure du \(Formatting.shortDate(measured)) et les courbes de l'OMS. La zone colorée montre l'incertitude."
    }

    // MARK: Upcoming needs

    @ViewBuilder
    private func upcoming(for child: Child, family: FamilySnapshot, needs: [Need]) -> some View {
        let ownCount = family.items.filter { $0.ownerID == child.id && $0.state == .active }.count
        sectionTitle("À venir")
        if ownCount < NeedsForecaster.minimumItemsForAdvice {
            EmptyStateView(
                symbol: "camera.fill",
                title: "Encore quelques photos",
                message: "Dès \(NeedsForecaster.minimumItemsForAdvice) vêtements, Mino anticipe ce dont \(child.name) aura besoin."
            ) {
                Button("Ajouter des vêtements", systemImage: "plus") { adding = child }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else if needs.isEmpty {
            EmptyStateView(
                symbol: "leaf.fill",
                title: "Rien ne manque",
                message: "Le dressing de \(child.name) est prêt pour les semaines à venir."
            )
        } else {
            ForEach(needs) { need in
                NeedRow(need: need, family: family)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.ink)
            .padding(.top, 4)
    }
}

private struct SizeBadge: View {
    let value: String
    let caption: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(caption)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NeedRow: View {
    let need: Need
    let family: FamilySnapshot

    var body: some View {
        let size = SizeChart.shortLabel(size: need.size, kind: need.group.sizeKind)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(need.group.displayName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("pour \(need.season.displayName)")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Text("\(need.missing) à prévoir en \(size), d'ici le \(Formatting.shortDate(need.neededBy))")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            if !need.familyStock.isEmpty {
                Label("Dans vos cartons", systemImage: "shippingbox.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(need.familyStock, id: \.self) { id in
                            GarmentImage(photo: family.garment(id)?.photo)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if need.stillMissing > 0 {
                Label("Reste à trouver : \(need.stillMissing)", systemImage: "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .minoCard()
    }
}

private struct GrowthChart: View {
    let profile: ChildProfile
    let color: Color

    private struct Point: Identifiable {
        let date: Date
        let estimate: Estimate
        var id: Date { date }
    }

    var body: some View {
        let now = Date.now
        let calendar = Calendar.current
        let points = (-6...12).compactMap { offset -> Point? in
            guard let date = calendar.date(byAdding: .month, value: offset, to: now), date >= profile.estimatedBirth else { return nil }
            return Point(date: date, estimate: profile.height(at: date))
        }
        let measured = profile.records.filter { $0.heightCM != nil && !$0.isApproximate }

        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Bas", point.estimate.low),
                    yEnd: .value("Haut", point.estimate.high)
                )
                .foregroundStyle(color.opacity(0.18))
                LineMark(x: .value("Date", point.date), y: .value("Taille", point.estimate.expected))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
            }
            ForEach(measured, id: \.date) { record in
                PointMark(x: .value("Date", record.date), y: .value("Taille", record.heightCM ?? 0))
                    .foregroundStyle(Theme.ink)
            }
            RuleMark(x: .value("Aujourd'hui", now))
                .foregroundStyle(Theme.secondaryText.opacity(0.4))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel("cm")
        .frame(height: 180)
        .accessibilityLabel("Projection de taille sur douze mois")
    }
}
