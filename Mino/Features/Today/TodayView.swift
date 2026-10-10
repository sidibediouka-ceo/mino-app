import MinoKit
import SwiftData
import SwiftUI
import WeatherKit

/// "Le soir, c'est prêt": the outfit of each child, and nothing else. From 4 pm the screen
/// shows tomorrow on its own. Planning and sorting live in the other tabs.
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
    @State private var dressingPlan: PlannedOutfit?

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
                VStack(alignment: .leading, spacing: 24) {
                    header(forecast: forecast)

                    ForEach(children) { child in
                        if let plan = plans.first(where: { $0.child?.id == child.id && calendar.isDate($0.day, inSameDayAs: day) }) {
                            OutfitCard(
                                child: child, color: children.color(of: child), plan: plan, family: family,
                                onSwap: { planner.swap($0, in: plan, forecast: forecast) },
                                onContext: { planner.setContext($0, for: plan, forecast: forecast) },
                                onDressing: { dressingPlan = plan },
                                onGaps: { router.showGrowth(of: child.id) }
                            )
                        }
                    }

                    if !reminderAsked && !plans.isEmpty {
                        reminderInvite
                    }

                    attribution
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar {
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
            planner.ensurePlans(for: day, forecast: weather.forecast(for: day))
            await scheduleReminders()
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
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
            Text(Formatting.longDate(.now))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            HStack(alignment: .center) {
                Text(showsTomorrow ? "Demain" : "Aujourd'hui")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(showsTomorrow ? "Aujourd'hui" : "Demain", systemImage: showsTomorrow ? "arrow.left" : "arrow.right") {
                    withAnimation(.snappy) { showsTomorrow.toggle() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Affiche les tenues de ce jour-là")
            }
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
