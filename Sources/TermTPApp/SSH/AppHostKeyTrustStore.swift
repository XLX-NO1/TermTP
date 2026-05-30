import Foundation
import TermTPCore

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

    static var defaultKnownHostsFileURLs: [URL] {
        [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".ssh", isDirectory: true)
                .appendingPathComponent("known_hosts"),
            TermTPKnownHostsFile.defaultFileURL
        ]
    }

    private let fileURL: URL
    private let knownHostsFileURLs: [URL]
    private var trustedKeys: [String: String]
    private var pendingRequests: [PendingHostKeyRequest] = []
    var pendingPrompt: HostKeyPrompt?
    var onPromptChanged: ((HostKeyPrompt?) -> Void)?

    init(
        fileURL: URL = AppHostKeyTrustStore.defaultFileURL,
        knownHostsFileURLs: [URL] = AppHostKeyTrustStore.defaultKnownHostsFileURLs
    ) {
        self.fileURL = fileURL
        self.knownHostsFileURLs = knownHostsFileURLs
        self.trustedKeys = (try? Self.loadTrustedKeys(from: fileURL)) ?? [:]
    }

    func trustedKey(host: String, port: UInt16) async -> String? {
        let hostPort = key(for: host, port: port)
        if let trustedKey = trustedKeys[hostPort] {
            return trustedKey
        }

        guard let knownHostKey = Self.loadKnownHost(hostPort: hostPort, from: knownHostsFileURLs) else {
            return nil
        }

        trustedKeys[hostPort] = knownHostKey
        try? Self.persistTrustedKeys(trustedKeys, to: fileURL)
        return knownHostKey
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
        return try JSONDecoder.termtp.decode([String: String].self, from: data)
    }

    private static func persistTrustedKeys(_ keys: [String: String], to fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.termtp.encode(keys)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func loadKnownHost(hostPort: String, from fileURLs: [URL]) -> String? {
        for fileURL in fileURLs {
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            for line in contents.split(whereSeparator: \.isNewline) {
                guard let knownHost = parseKnownHostLine(String(line)) else {
                    continue
                }

                if knownHost.hostPorts.contains(hostPort) {
                    return knownHost.key
                }
            }
        }

        return nil
    }

    private static func parseKnownHostLine(_ line: String) -> (hostPorts: [String], key: String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
            return nil
        }

        let parts = trimmedLine.split(separator: " ", omittingEmptySubsequences: true)
        let offset = parts.first?.hasPrefix("@") == true ? 1 : 0
        guard parts.count >= offset + 3 else {
            return nil
        }

        let hosts = parts[offset]
        guard !hosts.hasPrefix("|") else {
            return nil
        }

        let keyType = parts[offset + 1]
        let keyBody = parts[offset + 2]
        guard keyType.hasPrefix("ssh-") || keyType.hasPrefix("ecdsa-") else {
            return nil
        }

        let hostPorts = hosts
            .split(separator: ",")
            .compactMap(Self.hostPort(fromKnownHostsEntry:))
        guard !hostPorts.isEmpty else {
            return nil
        }

        return (hostPorts, "\(keyType) \(keyBody)")
    }

    private static func hostPort(fromKnownHostsEntry entry: Substring) -> String? {
        guard !entry.isEmpty else {
            return nil
        }

        if entry.first == "[" {
            guard
                let closingBracketIndex = entry.firstIndex(of: "]"),
                closingBracketIndex < entry.index(before: entry.endIndex)
            else {
                return nil
            }

            let host = entry[entry.index(after: entry.startIndex)..<closingBracketIndex]
            let separatorIndex = entry.index(after: closingBracketIndex)
            guard entry[separatorIndex] == ":" else {
                return nil
            }

            let port = entry[entry.index(after: separatorIndex)...]
            guard !host.isEmpty, UInt16(port) != nil else {
                return nil
            }

            return "\(host):\(port)"
        }

        return "\(entry):22"
    }
}

private struct PendingHostKeyRequest {
    var prompt: HostKeyPrompt
    var continuation: CheckedContinuation<Bool, Never>
}
