import MinoKit
import SwiftData
import SwiftUI
import WeatherKit

/// "Le soir, c'est prêt": the outfit of each child for today and tomorrow, and nothing else.
/// From 4 pm the screen opens on tomorrow. Planning and sorting live in the other tabs; past
/// outfits are kept in the journal.
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
    @State private var showingSettings = false
    @State private var showingJournal = false
    @State private var dressingPlan: PlannedOutfit?
    @State private var addingFor: Child?
    @State private var handMeDownFor: Child?
    @State private var editingPlan: PlannedOutfit?

    private let calendar = Calendar.current

    private var today: Date { calendar.startOfDay(for: .now) }

    private var tomorrow: Date { calendar.date(byAdding: .day, value: 1, to: today) ?? today }

    private var day: Date { showsTomorrow ? tomorrow : today }

    /// Changes whenever something that affects the plans changes.
    private var refreshKey: String {
        let wardrobe = garments.map { "\($0.id)\($0.stateRaw)\($0.owner?.id.uuidString ?? "")\($0.size)\($0.categoryRaw)" }
        let planned = plans.map { "\($0.day.timeIntervalSince1970)\($0.contextRaw)\($0.piecesRaw)" }
        return "\(today.timeIntervalSince1970)|\(weather.version)|\(children.map(\.id))|\(wardrobe.joined().hashValue)|\(planned.joined().hashValue)|\(reminderEnabled)|\(reminderMinutes)"
    }

    var body: some View {
        let family = FamilySnapshot(children: children, garments: garments)
        let forecast = weather.forecast(for: day)
        let planner = DayPlanner(family: family, context: context, calendar: calendar)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(forecast: forecast)

                    ForEach(children) { child in
                        if let plan = plans.first(where: { $0.child?.id == child.id && calendar.isDate($0.day, inSameDayAs: day) }) {
                            OutfitCard(
                                child: child, color: children.color(of: child), plan: plan, family: family,
                                availableFromFamily: family.availableGarments(for: child, on: .now).count,
                                onSwap: { planner.swap($0, in: plan, forecast: forecast) },
                                onContext: { planner.setContext($0, for: plan, forecast: forecast) },
                                onDressing: { dressingPlan = plan },
                                onGaps: { router.showGrowth(of: child.id) },
                                onAddGarments: { addingFor = child },
                                onTakeFromFamily: { handMeDownFor = child },
                                onEdit: { editingPlan = plan }
                            )
                        }
                    }

                    if !reminderAsked && !plans.isEmpty {
                        reminderInvite
                    }

                    if forecast.isEstimate {
                        weatherUnavailable
                    } else {
                        weatherAttribution
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingJournal = true } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel("Carnet des tenues")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel("Réglages")
                }
            }
        }
        .task(id: refreshKey) {
            await weather.refresh()
            guard !Task.isCancelled else { return }
            planner.ensurePlans(for: [today, tomorrow], forecast: weather.forecast(for:))
            await scheduleReminders()
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingJournal) { OutfitJournalView() }
        .sheet(item: $handMeDownFor) { HandMeDownView(child: $0, date: .now) }
        .sheet(item: $editingPlan) { plan in
            if let child = plan.child {
                OutfitComposerView(child: child, day: plan.day, existing: plan)
            }
        }
        .sheet(item: $addingFor) { child in
            NavigationStack {
                AddGarmentsView(owner: child, sizing: child.profile) { addingFor = nil }
                    .navigationTitle("Pour \(child.name)")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .fullScreenCover(item: $dressingPlan) { plan in
            DressingTogetherView(
                childName: plan.child?.name ?? "",
                color: plan.child.map { children.color(of: $0) } ?? Theme.accent,
                garments: plan.outfit.pieces.compactMap { family.garment($0.itemID) }
            ) {
                planner.confirm(plan)
            }
        }
    }

    // MARK: Sections

    private func header(forecast: DayForecast) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Jour", selection: $showsTomorrow.animation(.snappy)) {
                Text("Aujourd'hui").tag(false)
                Text("Demain").tag(true)
            }
            .pickerStyle(.segmented)
            Text(Formatting.longDate(day))
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 14) {
                Image(systemName: Formatting.symbol(for: forecast))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(forecast.morningC.rounded()))° le matin · \(Int(forecast.highC.rounded()))° l'après-midi")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(weatherNote(forecast))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func weatherNote(_ forecast: DayForecast) -> String {
        if forecast.isEstimate { return "Estimation de saison, météo indisponible" }
        if forecast.isRainy { return "Pluie probable (\(Int((forecast.precipitationChance * 100).rounded())) %)" }
        return forecast.condition == .clear ? "Grand soleil" : "Sans pluie"
    }

    private var reminderInvite: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chaque soir, demain est prêt", systemImage: "moon.stars.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
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

    /// Says why the weather is only a seasonal estimate, and how to get the real one.
    private var weatherUnavailable: some View {
        VStack(spacing: 8) {
            Text(weather.locationDenied
                 ? "Météo estimée selon la saison : autorisez la localisation pour la météo Apple du jour."
                 : "Météo estimée selon la saison : la météo Apple n'a pas pu être chargée.")
                .font(.caption)
                .multilineTextAlignment(.center)
            if weather.locationDenied, let settings = URL(string: UIApplication.openSettingsURLString) {
                Link("Ouvrir les réglages", destination: settings)
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(Theme.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// Required by WeatherKit wherever its data is shown: the Apple Weather mark and a link to
    /// the legal attribution page. Falls back to the text mark while the image loads.
    private var weatherAttribution: some View {
        let legalPage = weather.attribution?.legalPageURL ?? URL(string: "https://weatherkit.apple.com/legal-attribution.html")
        let mark = colorScheme == .dark ? weather.attribution?.combinedMarkDarkURL : weather.attribution?.combinedMarkLightURL
        return VStack(spacing: 6) {
            AsyncImage(url: mark) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text("\u{F8FF} Météo")
                    .font(.footnote.weight(.semibold))
            }
            .frame(height: 14)
            .accessibilityLabel("Données météo fournies par Apple Météo")
            if let legalPage {
                Link("Sources et mentions légales", destination: legalPage)
                    .font(.caption2)
            }
        }
        .foregroundStyle(Theme.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
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
