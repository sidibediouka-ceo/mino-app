import SwiftData
import SwiftUI

struct RootView: View {
    @Query(sort: \Child.createdAt) private var children: [Child]
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        Group {
            if onboardingCompleted && !children.isEmpty {
                TabView(selection: $router.tab) {
                    TodayView()
                        .tabItem { Label("Aujourd'hui", systemImage: "sun.horizon") }
                        .tag(AppTab.today)
                    WardrobeView()
                        .tabItem { Label("Dressing", systemImage: "hanger") }
                        .tag(AppTab.wardrobe)
                    GrowthView()
                        .tabItem { Label("Grandir", systemImage: "chart.line.uptrend.xyaxis") }
                        .tag(AppTab.growth)
                }
            } else {
                OnboardingView { onboardingCompleted = true }
            }
        }
        .onChange(of: children.isEmpty) { _, isEmpty in
            // Every child was removed: the next one deserves the full welcome, photos included.
            if isEmpty { onboardingCompleted = false }
        }
    }
}
