import SwiftUI
import UserNotifications

@main
struct FitsinMVPApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var session = AppSession()

    init() {
        Task { await APIClient.shared.warmUp() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isFullyAuthenticated {
                    RootTabView()
                        .environmentObject(session)
                        .onAppear { requestPushPermission() }
                } else if session.hasCode {
                    UserNameView()
                        .environmentObject(session)
                } else {
                    AccessCodeView()
                        .environmentObject(session)
                }
            }
        }
    }

    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
