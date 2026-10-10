import Charts
import MinoKit
import SwiftData
import SwiftUI

/// "La taille d'après": where the child is, where they are heading, and what the wardrobe
/// will need, family boxes first.
struct GrowthView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @State private var selectedID: UUID?
    @State private var measuring: Child?

    private var selected: Child? {
        children.first { $0.id == selectedID } ?? children.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if children.count > 1, let selected {
                        ChipPicker(options: children.map(\.id), selection: Binding(get: { selected.id }, set: { selectedID = $0 })) { id in
                            children.first { $0.id == id }?.name ?? ""
                        }
                    }
                    if let child = selected {
                        let family = FamilySnapshot(children: children, garments: garments)
                        let profile = child.profile
                        outlook(for: child, profile: profile)
                        needs(for: child, family: family)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Grandir")
            .sheet(item: $measuring) { MeasureView(child: $0) }
            .onChange(of: router.focusedChildID, initial: true) { _, id in
                if let id { selectedID = id }
            }
        }
    }

    // MARK: Outlook

    private func outlook(for child: Child, profile: ChildProfile) -> some View {
        let now = Date.now
        let clothing = profile.currentSize(.clothing, on: now)
        let shoes = profile.currentSize(.shoes, on: now)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Porte du \(SizeChart.label(size: clothing, kind: .clothing))")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.forest)
                    if let next = profile.nextSize(.clothing, after: now) {
                        Text("Passe en \(SizeChart.shortLabel(size: next.size, kind: .clothing)) \(Formatting.window(next.when))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(SizeChart.label(size: shoes, kind: .shoes))
                    .font(.headline)
                    .foregroundStyle(Theme.forest)
                if let next = profile.nextSize(.shoes, after: now) {
                    Text("Passe en \(next.size) \(Formatting.window(next.when))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            GrowthChart(profile: profile)

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
        return "D'après la mesure du \(Formatting.shortDate(measured)) et les courbes de l'OMS. La zone claire montre l'incertitude."
    }

    // MARK: Needs

    @ViewBuilder
    private func needs(for child: Child, family: FamilySnapshot) -> some View {
        let childNeeds = family.needs(on: .now, calendar: .current).filter { $0.childID == child.id }
        let ownCount = family.items.filter { $0.ownerID == child.id && $0.state == .active }.count

        Text("À venir")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.forest)
            .padding(.top, 6)

        if ownCount < NeedsForecaster.minimumItemsForAdvice {
            EmptyStateView(
                symbol: "camera",
                title: "Encore quelques photos",
                message: "Dès \(NeedsForecaster.minimumItemsForAdvice) vêtements, Mino anticipe ce dont \(child.name) aura besoin."
            )
        } else if childNeeds.isEmpty {
            EmptyStateView(
                symbol: "leaf",
                title: "Rien ne manque",
                message: "Le dressing de \(child.name) est prêt pour les semaines à venir."
            )
        } else {
            ForEach(childNeeds) { need in
                NeedRow(need: need, child: child, family: family)
            }
        }
    }
}

private struct NeedRow: View {
    let need: Need
    let child: Child
    let family: FamilySnapshot

    var body: some View {
        let size = SizeChart.shortLabel(size: need.size, kind: need.group.sizeKind)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(need.group.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.forest)
                Spacer()
                Text("pour \(need.season.displayName)")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Text("\(need.missing) à prévoir en \(size), d'ici le \(Formatting.shortDate(need.neededBy))")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            if !need.familyStock.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(need.familyStock, id: \.self) { id in
                            GarmentImage(photo: family.garment(id)?.photo)
                                .frame(width: 64, height: 64)
                        }
                    }
                }
                Button("Récupérer depuis les cartons", systemImage: "shippingbox") {
                    for id in need.familyStock {
                        family.garment(id)?.move(to: .active, owner: child)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            if need.stillMissing > 0 {
                Label("Reste à trouver : \(need.stillMissing)", systemImage: "magnifyingglass")
                    .font(.footnote)
                    .foregroundStyle(Theme.forest)
            }
        }
        .minoCard()
    }
}

private struct GrowthChart: View {
    let profile: ChildProfile

    private struct Point: Identifiable {
        let date: Date
        let estimate: Estimate
        var id: Date { date }
    }

    var body: some View {
        let now = Date.now
        let calendar = Calendar.current
        let points = (-6...12).compactMap { offset -> Point? in
            guard let date = calendar.date(byAdding: .month, value: offset, to: now), date >= profile.birthDate else { return nil }
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
                .foregroundStyle(Theme.sage.opacity(0.25))
                LineMark(x: .value("Date", point.date), y: .value("Taille", point.estimate.expected))
                    .foregroundStyle(Theme.sage)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
            ForEach(measured, id: \.date) { record in
                PointMark(x: .value("Date", record.date), y: .value("Taille", record.heightCM ?? 0))
                    .foregroundStyle(Theme.forest)
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
