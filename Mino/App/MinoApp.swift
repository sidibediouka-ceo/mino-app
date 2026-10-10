import SwiftData
import SwiftUI

@main
struct MinoApp: App {
    @State private var weather = WeatherStore()
    @State private var router = AppRouter()

    /// The family's data, kept on this iPhone across every app update. Model changes must stay
    /// additive (new properties with a default) so SwiftData migrates them in place; if the
    /// store ever cannot be opened, Mino says so instead of starting from an empty one.
    private let container: Result<ModelContainer, Error> = Result {
        try ModelContainer(for: Child.self, GrowthEntry.self, Garment.self, PlannedOutfit.self, CoveredNeed.self)
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .environment(weather)
                    .environment(router)
                    .tint(Theme.accent)
                    .modelContainer(container)
            case .failure:
                EmptyStateView(
                    symbol: "externaldrive.badge.exclamationmark",
                    title: "Vos données n'ont pas pu être ouvertes",
                    message: "Elles sont toujours sur cet iPhone. Installez la dernière version de Mino ou écrivez-nous : contact.mino.support@gmail.com"
                )
                .background(Theme.background)
            }
        }
    }
}
