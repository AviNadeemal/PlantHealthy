import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    private init() {}

    private let mobileKey = "agrismart_mobile"
    private let passwordKey = "agrismart_password"

    // MARK: - Save credentials after successful login
    func saveCredentials(mobile: String, password: String) {
        save(key: mobileKey, value: mobile)
        save(key: passwordKey, value: password)
    }

    // MARK: - Retrieve saved credentials (for Face ID login)
    func getCredentials() -> (mobile: String, password: String)? {
        guard let mobile = get(key: mobileKey),
              let password = get(key: passwordKey),
              !mobile.isEmpty, !password.isEmpty else { return nil }
        return (mobile, password)
    }

    // MARK: - Check if credentials are saved
    var hasCredentials: Bool {
        guard let mobile = get(key: mobileKey), !mobile.isEmpty else { return false }
        return true
    }

    // MARK: - Clear credentials on logout
    func clearCredentials() {
        delete(key: mobileKey)
        delete(key: passwordKey)
    }

    // MARK: - Private Keychain helpers
    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.isuru.agrismart",
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func get(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.isuru.agrismart",
            kSecAttrAccount: key,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: kCFBooleanTrue as Any
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.isuru.agrismart",
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
