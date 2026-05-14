import Citadel
import Crypto
import Foundation
import NIOCore
import NIOSSH

public struct HostKeyPrompt: Equatable, Sendable {
    public var host: String
    public var port: UInt16
    public var key: String
    public var fingerprint: String

    public init(host: String, port: UInt16, key: String, fingerprint: String) {
        self.host = host
        self.port = port
        self.key = key
        self.fingerprint = fingerprint
    }
}

public protocol HostKeyTrusting: Sendable {
    func trustedKey(host: String, port: UInt16) async -> String?
    func saveTrustedKey(_ key: String, host: String, port: UInt16) async throws
    func requestTrust(for prompt: HostKeyPrompt) async -> Bool
}

public actor InMemoryHostKeyTrustStore: HostKeyTrusting {
    private var trustedKeys: [String: String]
    public private(set) var prompts: [HostKeyPrompt] = []
    private let trustNewHosts: Bool

    public init(trustedKeys: [String: String] = [:], trustNewHosts: Bool = false) {
        self.trustedKeys = trustedKeys
        self.trustNewHosts = trustNewHosts
    }

    public func trustedKey(host: String, port: UInt16) async -> String? {
        trustedKeys[key(for: host, port: port)]
    }

    public func saveTrustedKey(_ key: String, host: String, port: UInt16) async throws {
        trustedKeys[self.key(for: host, port: port)] = key
    }

    public func requestTrust(for prompt: HostKeyPrompt) async -> Bool {
        prompts.append(prompt)
        if trustNewHosts {
            try? await saveTrustedKey(prompt.key, host: prompt.host, port: prompt.port)
        }
        return trustNewHosts
    }

    private func key(for host: String, port: UInt16) -> String {
        "\(host):\(port)"
    }
}

final class PromptingHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let store: any HostKeyTrusting

    init(host: String, port: UInt16, store: any HostKeyTrusting) {
        self.host = host
        self.port = port
        self.store = store
    }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let key = String(openSSHPublicKey: hostKey)
        let fingerprint = Self.fingerprint(for: key)

        validationCompletePromise.completeWithTask {
            if await self.store.trustedKey(host: self.host, port: self.port) == key {
                return
            }

            let prompt = HostKeyPrompt(
                host: self.host,
                port: self.port,
                key: key,
                fingerprint: fingerprint
            )

            if await self.store.requestTrust(for: prompt) {
                return
            }

            throw HostKeyRejectedError(host: self.host, port: self.port)
        }
    }

    static func fingerprint(for openSSHPublicKey: String) -> String {
        let digest = SHA256.hash(data: Data(openSSHPublicKey.utf8))
        return "SHA256:" + Data(digest).base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

public struct HostKeyRejectedError: Error, Equatable, CustomStringConvertible, Sendable {
    public var host: String
    public var port: UInt16

    public var description: String {
        "Host key rejected for \(host):\(port)"
    }
}
