import MinoKit
import SwiftData
import SwiftUI
import WeatherKit

/// "Le soir, c'est prêt": one outfit per child, explained, plus at most three useful things to do.
/// From 4 pm the screen switches to tomorrow on its own.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Environment(WeatherStore.self) private var weather
    @Environment(AppRouter.self) private var router
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @Query private var plans: [PlannedOutfit]
    @AppStorage("eveningReminderEnabled") private var reminderEnabled = false
    @AppStorage("eveningReminderAsked") private var reminderAsked = false
    @AppStorage("eveningReminderMinutes") private var reminderMinutes = 19 * 60 + 30
    @State private var showsTomorrow = Calendar.current.component(.hour, from: .now) >= 16
    @State private var sheet: TodaySheet?
    @State private var dressingPlan: PlannedOutfit?
    @State private var toast: String?

    private let calendar = Calendar.current

    private var day: Date {
        let today = calendar.startOfDay(for: .now)
        return showsTomorrow ? calendar.date(byAdding: .day, value: 1, to: today) ?? today : today
    }

    /// Changes whenever something that affects the plans changes.
    private var refreshKey: String {
        let wardrobe = garments.map { "\($0.id)\($0.stateRaw)\($0.owner?.id.uuidString ?? "")\($0.size)\($0.categoryRaw)" }
        return "\(day.timeIntervalSince1970)|\(weather.version)|\(children.map(\.id))|\(wardrobe.joined().hashValue)|\(reminderEnabled)|\(reminderMinutes)"
    }

    var body: some View {
        let family = FamilySnapshot(children: children, garments: garments)
        let forecast = weather.forecast(for: day)
        let planner = DayPlanner(family: family, context: context, calendar: calendar)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(forecast: forecast)

                    Picker("Jour", selection: $showsTomorrow) {
                        Text("Aujourd'hui").tag(false)
                        Text("Demain").tag(true)
                    }
                    .pickerStyle(.segmented)

                    ForEach(children) { child in
                        if let plan = plans.first(where: { $0.child?.id == child.id && calendar.isDate($0.day, inSameDayAs: day) }) {
                            OutfitCard(
                                child: child, plan: plan, family: family,
                                onSwap: { planner.swap($0, in: plan, forecast: forecast) },
                                onContext: { planner.setContext($0, for: plan, forecast: forecast) },
                                onConfirm: { planner.confirm(plan) },
                                onDressing: { dressingPlan = plan },
                                onGaps: { router.showGrowth(of: child.id) }
                            )
                        }
                    }

                    if !reminderAsked && !plans.isEmpty {
                        reminderInvite
                    }

                    let briefing = Briefing.compose(
                        family: family.profiles, items: family.items,
                        needs: family.needs(on: .now, calendar: calendar), on: .now
                    )
                    if !briefing.isEmpty {
                        Text("À prévoir")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.forest)
                            .padding(.top, 4)
                        ForEach(briefing) { item in
                            BriefingCard(content: content(for: item, family: family)) {
                                perform(item, family: family)
                            }
                        }
                    }

                    attribution
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .settings } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .overlay(alignment: .bottom) { toastView }
        }
        .task(id: refreshKey) {
            await weather.refresh()
            guard !Task.isCancelled else { return }
            planner.ensurePlans(for: day, forecast: weather.forecast(for: day))
            await scheduleReminders()
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add(let child):
                NavigationStack {
                    AddGarmentsView(owner: child, sizing: child.profile) { self.sheet = nil }
                        .navigationTitle("Ajouter")
                        .navigationBarTitleDisplayMode(.inline)
                }
            case .sort(let items):
                SortSessionView(garments: items, children: children)
            case .measure(let child):
                MeasureView(child: child)
            case .settings:
                SettingsView()
            }
        }
        .fullScreenCover(item: $dressingPlan) { plan in
            DressingTogetherView(
                childName: plan.child?.name ?? "",
                garments: plan.outfit.pieces.compactMap { family.garment($0.itemID) }
            ) {
                planner.confirm(plan)
            }
        }
    }

    // MARK: Sections

    private func header(forecast: DayForecast) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.component(.hour, from: .now) < 18 ? "Bonjour" : "Bonsoir")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.forest)
                Text(Formatting.longDate(.now))
                    .foregroundStyle(Theme.secondaryText)
            }
            HStack(spacing: 8) {
                Image(systemName: Formatting.symbol(for: forecast))
                    .symbolRenderingMode(.multicolor)
                Text(showsTomorrow ? "Demain" : "Aujourd'hui").fontWeight(.semibold)
                Text(Formatting.forecast(forecast))
                if forecast.isEstimate {
                    Text("· estimation de saison").foregroundStyle(Theme.secondaryText)
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.forest)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.card, in: Capsule())
            .accessibilityElement(children: .combine)
        }
    }

    private var reminderInvite: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chaque soir, demain est prêt", systemImage: "moon.stars")
                .font(.headline)
                .foregroundStyle(Theme.forest)
            Text("Mino peut vous prévenir à 19 h 30 avec la météo du lendemain. Une seule notification, jamais de publicité.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            HStack {
                Button("Non merci") { reminderAsked = true }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Oui, chaque soir") {
                    reminderAsked = true
                    Task { reminderEnabled = await EveningReminder.requestPermission() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .minoCard()
    }

    @ViewBuilder
    private var attribution: some View {
        if let attribution = weather.attribution {
            HStack(spacing: 8) {
                AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    EmptyView()
                }
                .frame(height: 12)
                Link("Sources météo", destination: attribution.legalPageURL)
            }
            .font(.caption2)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.onForest)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(Theme.forest, in: Capsule())
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast)
                .task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation { self.toast = nil }
                }
        }
    }

    // MARK: Briefing

    private func content(for item: BriefingItem, family: FamilySnapshot) -> BriefingContent {
        let name = { (id: UUID) in family.child(id)?.name ?? "" }
        switch item {
        case .addGarments(let childID):
            return BriefingContent(
                symbol: "camera", title: "La garde-robe de \(name(childID))",
                message: "Quelques photos de plus et Mino préparera des tenues plus variées.", action: "Ajouter des vêtements"
            )
        case .sort(let childID, let itemIDs):
            return BriefingContent(
                symbol: "arrow.triangle.2.circlepath",
                title: "\(Formatting.count(itemIDs.count, "vêtement trop petit", "vêtements trop petits")) pour \(name(childID))",
                message: "Une minute pour décider : frère ou sœur, cartons, don ou vente.", action: "Trier"
            )
        case .retrieve(let need):
            let size = SizeChart.shortLabel(size: need.size, kind: need.group.sizeKind)
            return BriefingContent(
                symbol: "shippingbox", title: "Déjà dans vos cartons",
                message: "\(need.group.displayName) : \(Formatting.count(need.familyStock.count, "pièce", "pièces")) en \(size) pour \(name(need.childID)), pour \(need.season.displayName). Inutile d'acheter.",
                action: "Récupérer"
            )
        case .prepare(let need):
            let size = SizeChart.shortLabel(size: need.size, kind: need.group.sizeKind)
            return BriefingContent(
                symbol: "calendar", title: "\(need.group.displayName) pour \(name(need.childID))",
                message: "Il en manquera \(need.stillMissing) en \(size) d'ici le \(Formatting.shortDate(need.neededBy)).",
                action: "Voir"
            )
        case .sizeUp(let childID, let milestone):
            return BriefingContent(
                symbol: "ruler", title: "\(name(childID)) passe bientôt en \(SizeChart.shortLabel(size: milestone.size, kind: milestone.kind))",
                message: "\(Formatting.sentence(Formatting.window(milestone.when))). Mino a déjà regardé ce qui l'attend.",
                action: "Voir"
            )
        case .measure(let childID):
            return BriefingContent(
                symbol: "ruler", title: "Mesurer \(name(childID)) ?",
                message: "Trente secondes pour des prévisions de taille plus justes.", action: "Mesurer"
            )
        }
    }

    private func perform(_ item: BriefingItem, family: FamilySnapshot) {
        switch item {
        case .addGarments(let childID):
            if let child = family.child(childID) { sheet = .add(child) }
        case .sort(_, let itemIDs):
            sheet = .sort(itemIDs.compactMap(family.garment))
        case .retrieve(let need):
            guard let child = family.child(need.childID) else { return }
            for id in need.familyStock {
                family.garment(id)?.move(to: .active, owner: child)
            }
            withAnimation {
                toast = "\(Formatting.count(need.familyStock.count, "pièce ajoutée", "pièces ajoutées")) au dressing de \(child.name)"
            }
        case .prepare(let need):
            router.showGrowth(of: need.childID)
        case .sizeUp(let childID, _):
            router.showGrowth(of: childID)
        case .measure(let childID):
            if let child = family.child(childID) { sheet = .measure(child) }
        }
    }

    private func scheduleReminders() async {
        guard reminderEnabled else { return }
        let names = Formatting.names(children.map(\.name))
        let plural = children.count > 1
        await EveningReminder.schedule(minutesAfterMidnight: reminderMinutes, calendar: calendar) { day in
            let forecast = weather.forecast(for: day)
            let outlook = forecast.isEstimate ? "" : "\(Formatting.forecast(forecast)). "
            return outlook + (plural ? "Les tenues de \(names) sont prêtes." : "La tenue de \(names) est prête.")
        }
    }
}

private enum TodaySheet: Identifiable {
    case add(Child)
    case sort([Garment])
    case measure(Child)
    case settings

    var id: String {
        switch self {
        case .add(let child): return "add-\(child.id)"
        case .sort(let garments): return "sort-\(garments.map(\.id))"
        case .measure(let child): return "measure-\(child.id)"
        case .settings: return "settings"
        }
    }
}
