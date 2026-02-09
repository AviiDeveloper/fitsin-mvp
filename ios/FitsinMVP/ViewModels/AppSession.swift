import Foundation

@MainActor
final class AppSession: ObservableObject {
    @Published var hasCode = false

    init() {
        hasCode = (KeychainStore.readCode()?.isEmpty == false)
    }

    func save(code: String) {
        guard !code.isEmpty else { return }
        hasCode = KeychainStore.saveCode(code)
    }

    func signOut() {
        KeychainStore.clearCode()
        hasCode = false
    }
}
