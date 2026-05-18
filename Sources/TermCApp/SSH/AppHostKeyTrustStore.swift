import Foundation
import TermCCore

@MainActor
final class AppHostKeyTrustStore: HostKeyTrusting, @unchecked Sendable {
    struct TrustedHostKey: Identifiable, Equatable {
        var id: String { hostPort }
        var hostPort: String
        var key: String
    }

    private let defaults: UserDefaults
    private let defaultsKey = "TermTP.trustedHostKeys"
    private var trustedKeys: [String: String]
    private var pendingContinuation: CheckedContinuation<Bool, Never>?
    var pendingPrompt: HostKeyPrompt?
    var onPromptChanged: ((HostKeyPrompt?) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.trustedKeys = defaults.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }

    func trustedKey(host: String, port: UInt16) async -> String? {
        trustedKeys[key(for: host, port: port)]
    }

    func saveTrustedKey(_ key: String, host: String, port: UInt16) async throws {
        trustedKeys[self.key(for: host, port: port)] = key
        defaults.set(trustedKeys, forKey: defaultsKey)
    }

    var trustedHostKeys: [TrustedHostKey] {
        trustedKeys
            .map { TrustedHostKey(hostPort: $0.key, key: $0.value) }
            .sorted { $0.hostPort < $1.hostPort }
    }

    func removeTrustedKey(hostPort: String) {
        trustedKeys[hostPort] = nil
        defaults.set(trustedKeys, forKey: defaultsKey)
    }

    func clearTrustedKeys() {
        trustedKeys.removeAll()
        defaults.set(trustedKeys, forKey: defaultsKey)
    }

    func requestTrust(for prompt: HostKeyPrompt) async -> Bool {
        pendingPrompt = prompt
        onPromptChanged?(prompt)
        return await withCheckedContinuation { continuation in
            pendingContinuation = continuation
        }
    }

    func resolvePendingPrompt(trusted: Bool) {
        if trusted, let pendingPrompt {
            trustedKeys[key(for: pendingPrompt.host, port: pendingPrompt.port)] = pendingPrompt.key
            defaults.set(trustedKeys, forKey: defaultsKey)
        }

        pendingPrompt = nil
        onPromptChanged?(nil)
        pendingContinuation?.resume(returning: trusted)
        pendingContinuation = nil
    }

    private func key(for host: String, port: UInt16) -> String {
        "\(host):\(port)"
    }
}
