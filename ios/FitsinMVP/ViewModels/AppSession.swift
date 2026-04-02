import Foundation

@MainActor
final class AppSession: ObservableObject {
    @Published var userName: String?
    @Published var pinVerified = false

    var isFullyAuthenticated: Bool { userName != nil && pinVerified }

    init() {
        let stored = KeychainStore.readName()
        userName = (stored?.isEmpty == false) ? stored : nil
        pinVerified = false
    }

    func saveName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if KeychainStore.saveName(trimmed) {
            userName = trimmed
            pinVerified = true
        }
    }

    func verifyPin() {
        pinVerified = true
    }

    func switchUser() {
        KeychainStore.clearName()
        userName = nil
        pinVerified = false
    }

    func signOut() {
        KeychainStore.clearName()
        userName = nil
        pinVerified = false
    }
}
