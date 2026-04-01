import SwiftUI

@main
struct FitsinMVPApp: App {
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
}
