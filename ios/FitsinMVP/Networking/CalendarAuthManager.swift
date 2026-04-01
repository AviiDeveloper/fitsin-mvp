import Foundation
import GoogleSignIn

@MainActor
final class CalendarAuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var userDisplayName: String?

    private let calendarScope = "https://www.googleapis.com/auth/calendar"

    init() {
        updateState()
    }

    func restorePreviousSignIn() async {
        do {
            try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let user = GIDSignIn.sharedInstance.currentUser
            if let user, !user.grantedScopes!.contains(calendarScope) {
                guard let vc = UIApplication.shared.topViewController else { return }
                try await user.addScopes([calendarScope], presenting: vc)
            }
            updateState()
        } catch {
            updateState()
        }
    }

    func signIn() async throws {
        guard let vc = UIApplication.shared.topViewController else {
            throw CalendarAuthError.noViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: vc, hint: nil, additionalScopes: [calendarScope])
        _ = result.user
        updateState()
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
        userDisplayName = nil
    }

    func validAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw CalendarAuthError.notSignedIn
        }

        try await user.refreshTokensIfNeeded()
        guard let token = user.accessToken.tokenString as String? else {
            throw CalendarAuthError.notSignedIn
        }
        return token
    }

    private func updateState() {
        let user = GIDSignIn.sharedInstance.currentUser
        isSignedIn = user != nil
        userEmail = user?.profile?.email
        userDisplayName = user?.profile?.name
    }
}

enum CalendarAuthError: Error {
    case notSignedIn
    case noViewController
}
