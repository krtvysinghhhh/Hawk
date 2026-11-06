import Foundation
import Security
import HawkCore

/// Thread-safe actor encapsulating Apple Keychain Services.
///
/// Stores sensitive authentication credentials (YouTube Music cookies, Spotify OAuth tokens)
/// into Apple Keychain Services with accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
public actor KeychainStore {
    public static let shared = KeychainStore()

    public let serviceName: String
    public let isInMemoryOnly: Bool
    private var inMemoryStorage: [String: Data] = [:]

    /// Initializes a Keychain store.
    /// - Parameters:
    ///   - serviceName: Reverse-DNS service identifier.
    ///   - inMemoryOnly: Set to true only in automated test harness environments where Keychain entitlements are unavailable.
    public init(serviceName: String = "com.hawk.music.auth", inMemoryOnly: Bool = false) {
        self.serviceName = serviceName
        self.isInMemoryOnly = inMemoryOnly
    }

    /// Persists sensitive binary data into the Keychain using atomic upsert (preventing credential loss).
    public func save(key: String, data: Data) throws {
        if isInMemoryOnly {
            inMemoryStorage[key] = data
            return
        }

        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var insertQuery = searchQuery
            insertQuery[kSecValueData as String] = data
            insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw HawkError.keychainError("SecItemAdd failed for key '\(key)' with OSStatus: \(addStatus)")
            }
            return
        }

        throw HawkError.keychainError("SecItemUpdate failed for key '\(key)' with OSStatus: \(updateStatus)")
    }

    /// Reads sensitive binary data from the Keychain.
    public func read(key: String) throws -> Data? {
        if isInMemoryOnly {
            return inMemoryStorage[key]
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw HawkError.keychainError("SecItemCopyMatching failed for key '\(key)' with OSStatus: \(status)")
        }
    }

    /// Removes an item from the Keychain.
    public func delete(key: String) throws {
        if isInMemoryOnly {
            inMemoryStorage.removeValue(forKey: key)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HawkError.keychainError("SecItemDelete failed for key '\(key)' with OSStatus: \(status)")
        }
    }

    // MARK: - Convenience String Helpers
    public func saveString(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw HawkError.keychainError("Invalid string UTF-8 encoding for key '\(key)'")
        }
        try save(key: key, data: data)
    }

    public func readString(key: String) throws -> String? {
        guard let data = try read(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
