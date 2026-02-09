import SwiftUI

@main
struct FitsinMVPApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.hasCode {
                    RootTabView()
                        .environmentObject(session)
                } else {
                    AccessCodeView()
                        .environmentObject(session)
                }
            }
        }
    }
}
