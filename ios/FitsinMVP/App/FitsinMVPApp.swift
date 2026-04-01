import SwiftUI
import UserNotifications
import GoogleSignIn

@main
struct FitsinMVPApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var session = AppSession()
    @StateObject private var calendarAuth = CalendarAuthManager()

    init() {
        Task { await APIClient.shared.warmUp() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isFullyAuthenticated {
                    RootTabView()
                        .environmentObject(session)
                        .environmentObject(calendarAuth)
                        .onAppear {
                            requestPushPermission()
                            CalendarService.shared.authManager = calendarAuth
                            Task { await calendarAuth.restorePreviousSignIn() }
                        }
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
