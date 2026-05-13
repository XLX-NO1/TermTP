import Foundation
import Security

public enum Credential: Equatable, Sendable {
    case password(String)
    case privateKeyPassphrase(String)
}

public protocol CredentialStoring: Sendable {
    func save(_ credential: Credential, for connectionID: UUID) async throws
    func load(for connectionID: UUID) async throws -> Credential?
    func delete(for connectionID: UUID) async throws
}

public actor InMemoryCredentialStore: CredentialStoring {
    private var storage: [UUID: Credential] = [:]

    public init() {}

    public func save(_ credential: Credential, for connectionID: UUID) async throws {
        storage[connectionID] = credential
    }

    public func load(for connectionID: UUID) async throws -> Credential? {
        storage[connectionID]
    }

    public func delete(for connectionID: UUID) async throws {
        storage[connectionID] = nil
    }
}

public struct KeychainCredentialStore: CredentialStoring {
    private let service = "local.termc.credentials"

    public init() {}

    public func save(_ credential: Credential, for connectionID: UUID) async throws {
        try await delete(for: connectionID)
        let data = try JSONEncoder.termc.encode(KeychainPayload(credential: credential))
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectionID.uuidString,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public func load(for connectionID: UUID) async throws -> Credential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectionID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError.status(status) }
        return try JSONDecoder.termc.decode(KeychainPayload.self, from: data).credential
    }

    public func delete(for connectionID: UUID) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectionID.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }
}

private struct KeychainPayload: Codable {
    var kind: String
    var value: String

    init(credential: Credential) {
        switch credential {
        case .password(let value):
            self.kind = "password"
            self.value = value
        case .privateKeyPassphrase(let value):
            self.kind = "privateKeyPassphrase"
            self.value = value
        }
    }

    var credential: Credential {
        kind == "privateKeyPassphrase" ? .privateKeyPassphrase(value) : .password(value)
    }
}

public enum KeychainError: Error, Equatable {
    case status(OSStatus)
}
