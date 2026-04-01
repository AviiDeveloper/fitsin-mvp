import Foundation

@MainActor
final class AppSession: ObservableObject {
    @Published var hasCode = false
    @Published var userName: String?

    var isFullyAuthenticated: Bool { hasCode && userName != nil }

    init() {
        hasCode = (KeychainStore.readCode()?.isEmpty == false)
        let stored = KeychainStore.readName()
        userName = (stored?.isEmpty == false) ? stored : nil
    }

    func save(code: String) {
        guard !code.isEmpty else { return }
        hasCode = KeychainStore.saveCode(code)
    }

    func saveName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if KeychainStore.saveName(trimmed) {
            userName = trimmed
        }
    }

    func switchUser() {
        KeychainStore.clearName()
        userName = nil
    }

    func signOut() {
        KeychainStore.clearCode()
        KeychainStore.clearName()
        hasCode = false
        userName = nil
    }
}
