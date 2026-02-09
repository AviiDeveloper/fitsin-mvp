import SwiftUI

struct RootTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BrandTheme.surfaceStrong)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(BrandTheme.ink)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(BrandTheme.ink)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(BrandTheme.inkSoft)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(BrandTheme.inkSoft)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "chart.line.uptrend.xyaxis")
                }

            MonthView()
                .tabItem {
                    Label("Month", systemImage: "calendar")
                }

            EventsView()
                .tabItem {
                    Label("Events", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(BrandTheme.ink)
    }
}
