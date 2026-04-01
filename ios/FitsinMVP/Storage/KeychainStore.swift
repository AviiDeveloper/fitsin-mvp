import Foundation
import Security

enum KeychainStore {
    private static let service = "com.fitsin.m3"
    private static let codeAccount = "app_shared_code"
    private static let nameAccount = "app_user_name"

    // MARK: - Access Code

    static func saveCode(_ code: String) -> Bool {
        save(value: code, account: codeAccount)
    }

    static func readCode() -> String? {
        read(account: codeAccount)
    }

    static func clearCode() {
        delete(account: codeAccount)
    }

    // MARK: - User Name

    static func saveName(_ name: String) -> Bool {
        save(value: name, account: nameAccount)
    }

    static func readName() -> String? {
        read(account: nameAccount)
    }

    static func clearName() {
        delete(account: nameAccount)
    }

    // MARK: - Private

    private static func save(value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
