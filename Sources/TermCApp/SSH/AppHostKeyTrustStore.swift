import Foundation
import TermCCore

@MainActor
final class AppHostKeyTrustStore: HostKeyTrusting, @unchecked Sendable {
    struct TrustedHostKey: Identifiable, Equatable {
        var id: String { hostPort }
        var hostPort: String
        var key: String
    }

    static var defaultFileURL: URL {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("TermTPTests-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("trusted-host-keys.json")
        }

        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TermTP", isDirectory: true)
            .appendingPathComponent("trusted-host-keys.json")
    }

    private let fileURL: URL
    private var trustedKeys: [String: String]
    private var pendingRequests: [PendingHostKeyRequest] = []
    var pendingPrompt: HostKeyPrompt?
    var onPromptChanged: ((HostKeyPrompt?) -> Void)?

    init(fileURL: URL = AppHostKeyTrustStore.defaultFileURL) {
        self.fileURL = fileURL
        self.trustedKeys = (try? Self.loadTrustedKeys(from: fileURL)) ?? [:]
    }

    func trustedKey(host: String, port: UInt16) async -> String? {
        trustedKeys[key(for: host, port: port)]
    }

    func saveTrustedKey(_ key: String, host: String, port: UInt16) async throws {
        trustedKeys[self.key(for: host, port: port)] = key
        try Self.persistTrustedKeys(trustedKeys, to: fileURL)
    }

    var trustedHostKeys: [TrustedHostKey] {
        trustedKeys
            .map { TrustedHostKey(hostPort: $0.key, key: $0.value) }
            .sorted { $0.hostPort < $1.hostPort }
    }

    func removeTrustedKey(hostPort: String) {
        trustedKeys[hostPort] = nil
        try? Self.persistTrustedKeys(trustedKeys, to: fileURL)
    }

    func clearTrustedKeys() {
        trustedKeys.removeAll()
        try? Self.persistTrustedKeys(trustedKeys, to: fileURL)
    }

    func requestTrust(for prompt: HostKeyPrompt) async -> Bool {
        return await withCheckedContinuation { continuation in
            pendingRequests.append(PendingHostKeyRequest(prompt: prompt, continuation: continuation))
            presentNextPromptIfNeeded()
        }
    }

    func resolvePendingPrompt(trusted: Bool) {
        guard !pendingRequests.isEmpty else {
            pendingPrompt = nil
            onPromptChanged?(nil)
            return
        }

        let request = pendingRequests.removeFirst()
        if trusted {
            trustedKeys[key(for: request.prompt.host, port: request.prompt.port)] = request.prompt.key
            try? Self.persistTrustedKeys(trustedKeys, to: fileURL)
        }

        pendingPrompt = nil
        request.continuation.resume(returning: trusted)
        presentNextPromptIfNeeded()
    }

    private func presentNextPromptIfNeeded() {
        guard pendingPrompt == nil else {
            return
        }

        pendingPrompt = pendingRequests.first?.prompt
        onPromptChanged?(pendingPrompt)
    }

    private func key(for host: String, port: UInt16) -> String {
        "\(host):\(port)"
    }

    private static func loadTrustedKeys(from fileURL: URL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.termc.decode([String: String].self, from: data)
    }

    private static func persistTrustedKeys(_ keys: [String: String], to fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.termc.encode(keys)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}

private struct PendingHostKeyRequest {
    var prompt: HostKeyPrompt
    var continuation: CheckedContinuation<Bool, Never>
}
