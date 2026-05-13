import Citadel
import Crypto
import Foundation

extension SSHClient: @retroactive @unchecked Sendable {}

public struct SSHConfigurationSummary: Equatable, Sendable {
    public var host: String
    public var port: UInt16
    public var username: String
    public var authenticationKind: AuthenticationKind
    public var privateKeyPath: String?

    public init(record: ConnectionRecord, credential: Credential?) {
        self.host = record.host
        self.port = record.port
        self.username = record.username
        self.authenticationKind = record.authentication.kind

        if case .publicKey(let privateKeyPath) = record.authentication {
            self.privateKeyPath = privateKeyPath
        } else {
            self.privateKeyPath = nil
        }
    }
}

public enum SSHClientAdapterError: Error, Equatable {
    case missingCredential
    case invalidPrivateKey
    case unsupportedPrivateKey
}

public struct CitadelSSHClient: SSHClientProviding {
    public init() {}

    public func connect(record: ConnectionRecord, credential: Credential?) async throws -> SSHSessionProviding {
        let client = try await SSHClient.connect(
            host: record.host,
            port: Int(record.port),
            authenticationMethod: try authenticationMethod(for: record, credential: credential),
            hostKeyValidator: .acceptAnything(),
            reconnect: .never
        )

        return CitadelSSHSession(record: record, client: client)
    }

    private func authenticationMethod(for record: ConnectionRecord, credential: Credential?) throws -> SSHAuthenticationMethod {
        switch record.authentication {
        case .password:
            guard case .password(let password) = credential else {
                throw SSHClientAdapterError.missingCredential
            }
            return .passwordBased(username: record.username, password: password)

        case .publicKey(let privateKeyPath):
            guard let key = try? String(contentsOfFile: privateKeyPath, encoding: .utf8) else {
                throw SSHClientAdapterError.invalidPrivateKey
            }
            let decryptionKey = privateKeyPassphraseData(from: credential)

            switch try SSHKeyDetection.detectPrivateKeyType(from: key) {
            case .ed25519:
                let privateKey = try Curve25519.Signing.PrivateKey(sshEd25519: key, decryptionKey: decryptionKey)
                return .ed25519(username: record.username, privateKey: privateKey)
            case .rsa:
                let privateKey = try Insecure.RSA.PrivateKey(sshRsa: key, decryptionKey: decryptionKey)
                return .rsa(username: record.username, privateKey: privateKey)
            default:
                throw SSHClientAdapterError.unsupportedPrivateKey
            }
        }
    }

    private func privateKeyPassphraseData(from credential: Credential?) -> Data? {
        guard case .privateKeyPassphrase(let passphrase) = credential else {
            return nil
        }
        return passphrase.data(using: .utf8)
    }
}

public actor CitadelSSHSession: SSHSessionProviding {
    public let id = UUID()
    public let record: ConnectionRecord
    private let client: SSHClient
    private var currentState: SSHSessionState = .connected
    private var output = ""

    public init(record: ConnectionRecord, client: SSHClient) {
        self.record = record
        self.client = client
    }

    public var state: SSHSessionState {
        currentState
    }

    public func send(_ input: String) async throws {
        output += input
    }

    public func drainOutput() async -> String {
        let value = output
        output.removeAll()
        return value
    }

    public func disconnect() async throws {
        try await client.close()
        currentState = .disconnected
    }
}
