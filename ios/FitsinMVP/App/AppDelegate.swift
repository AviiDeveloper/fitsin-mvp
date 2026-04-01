import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        _ = KeychainStore.saveDeviceToken(token)

        // Register with backend
        let name = KeychainStore.readName() ?? ""
        guard !name.isEmpty else { return }

        Task {
            try? await APIClient.shared.registerDevice(
                token: token,
                name: name,
                preferences: [
                    "new_sale": true,
                    "my_commission_sale": false,
                    "daily_summary": true,
                    "rota_reminder": true
                ]
            )
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[push] Registration failed: \(error.localizedDescription)")
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Handle notification tap — could navigate to relevant screen
    }
}
