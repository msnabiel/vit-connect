import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    private let service = "com.vtopchennai.credentials"

    // MARK: - Save Credentials
    func save(username: String, password: String) -> Bool {
        // Delete existing credentials first
        delete(key: "username")
        delete(key: "password")

        // Save username
        guard saveToKeychain(key: "username", value: username) else {
            return false
        }

        // Save password
        return saveToKeychain(key: "password", value: password)
    }

    // MARK: - Get Credentials
    func getUsername() -> String? {
        return retrieveFromKeychain(key: "username")
    }

    func getPassword() -> String? {
        return retrieveFromKeychain(key: "password")
    }

    // MARK: - Delete Credentials
    func deleteAll() {
        delete(key: "username")
        delete(key: "password")
    }

    // MARK: - Private Methods
    private func saveToKeychain(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func retrieveFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
