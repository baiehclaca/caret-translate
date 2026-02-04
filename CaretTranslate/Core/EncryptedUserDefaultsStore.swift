import CryptoKit
import Foundation
import Security

public protocol SymmetricKeyProvider {
    func loadKey() throws -> SymmetricKey?
    func saveKey(_ key: SymmetricKey) throws
}

public final class KeychainKeyProvider: SymmetricKeyProvider {
    private let service: String
    private let account: String

    public init(service: String = "CaretTranslate", account: String = "encryption-key") {
        self.service = service
        self.account = account
    }

    public func loadKey() throws -> SymmetricKey? {
        var item: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        return SymmetricKey(data: data)
    }

    public func saveKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: keyData
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandled(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }
}

public final class EncryptedUserDefaultsStore {
    private let userDefaults: UserDefaults
    private let keyProvider: SymmetricKeyProvider

    public init(userDefaults: UserDefaults = .standard, keyProvider: SymmetricKeyProvider = KeychainKeyProvider()) {
        self.userDefaults = userDefaults
        self.keyProvider = keyProvider
    }

    public func set(_ value: String?, forKey key: String) throws {
        guard let value else {
            userDefaults.removeObject(forKey: key)
            return
        }
        let symmetricKey = try loadOrCreateKey()
        let data = Data(value.utf8)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        userDefaults.set(sealedBox.combined, forKey: key)
    }

    public func string(forKey key: String) throws -> String? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        let symmetricKey = try loadOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
        return String(data: decrypted, encoding: .utf8)
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try keyProvider.loadKey() {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try keyProvider.saveKey(newKey)
        return newKey
    }
}

public enum KeychainError: Error {
    case invalidData
    case unhandled(OSStatus)
}
