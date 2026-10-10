import MinoKit
import SwiftData
import SwiftUI

struct RootView: View {
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @Environment(AppRouter.self) private var router

    /// Things worth a gesture (sorting, boxes, measuring): a quiet badge, never on the home screen.
    private var toDoCount: Int {
        let family = FamilySnapshot(children: children, garments: garments)
        return Briefing.compose(
            family: family.profiles, items: family.items, needs: family.needs(on: .now, calendar: .current), on: .now
        ).count
    }

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
                        .badge(toDoCount)
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
