import SwiftUI
import UIKit

struct RootTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BrandTheme.paper).withAlphaComponent(0.98)
        appearance.shadowColor = UIColor(BrandTheme.outline)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(BrandTheme.ink)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(BrandTheme.ink),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(BrandTheme.inkSoft)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(BrandTheme.inkSoft),
            .font: UIFont.systemFont(ofSize: 11, weight: .regular)
        ]
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
