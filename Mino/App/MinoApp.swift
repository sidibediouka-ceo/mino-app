import SwiftData
import SwiftUI

@main
struct MinoApp: App {
    @State private var weather = WeatherStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(weather)
                .environment(router)
                .tint(Theme.accent)
        }
        .modelContainer(for: [Child.self, GrowthEntry.self, Garment.self, PlannedOutfit.self])
    }
}
