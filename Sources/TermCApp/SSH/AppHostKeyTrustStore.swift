import Foundation
import TermCCore

@MainActor
final class AppHostKeyTrustStore: HostKeyTrusting, @unchecked Sendable {
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
