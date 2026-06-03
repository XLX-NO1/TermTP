import Foundation

enum TermTPKnownHostsFile {
    static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".termtp", isDirectory: true)
            .appendingPathComponent("known_hosts")
    }

    static var legacyFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TermTP", isDirectory: true)
            .appendingPathComponent("known_hosts")
    }

    static func migrateLegacyFileIfNeeded(to fileURL: URL = defaultFileURL, from legacyFileURL: URL = legacyFileURL) {
        guard
            !FileManager.default.fileExists(atPath: fileURL.path),
            FileManager.default.fileExists(atPath: legacyFileURL.path)
        else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: legacyFileURL, to: fileURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch {
            return
        }
    }

    static func removeEntry(host: String, port: UInt16, from fileURL: URL = defaultFileURL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let hostPatterns: Set<String>
        if port == 22 {
            hostPatterns = Set([host, "[\(host)]:\(port)"])
        } else {
            hostPatterns = Set(["[\(host)]:\(port)"])
        }
        let lines = try String(contentsOf: fileURL, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                guard let firstField = line.split(separator: " ", maxSplits: 1).first else {
                    return true
                }

                let patterns = firstField.split(separator: ",").map(String.init)
                return patterns.allSatisfy { !hostPatterns.contains($0) }
            }

        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func trustedKey(host: String, port: UInt16, from fileURL: URL = defaultFileURL) throws -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let hostPatterns: Set<String>
        if port == 22 {
            hostPatterns = Set([host, "[\(host)]:\(port)"])
        } else {
            hostPatterns = Set(["[\(host)]:\(port)"])
        }

        for line in try String(contentsOf: fileURL, encoding: .utf8).split(separator: "\n") {
            guard let entry = KnownHostEntry(line: String(line)),
                  entry.hosts.contains(where: { hostPatterns.contains($0) })
            else {
                continue
            }

            return entry.publicKey
        }

        return nil
    }

    static func trustedKeys(from fileURL: URL = defaultFileURL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        var trustedKeys: [String: String] = [:]
        for line in try String(contentsOf: fileURL, encoding: .utf8).split(separator: "\n") {
            guard let entry = KnownHostEntry(line: String(line)) else {
                continue
            }

            for host in entry.hosts {
                guard let hostPort = hostPort(from: host) else {
                    continue
                }
                trustedKeys[hostPort] = entry.publicKey
            }
        }

        return trustedKeys
    }

    private static func hostPort(from knownHostPattern: String) -> String? {
        guard !knownHostPattern.isEmpty, !knownHostPattern.hasPrefix("|") else {
            return nil
        }

        if knownHostPattern.hasPrefix("["),
           let closingBracket = knownHostPattern.firstIndex(of: "]"),
           knownHostPattern.index(after: closingBracket) < knownHostPattern.endIndex,
           knownHostPattern[knownHostPattern.index(after: closingBracket)] == ":" {
            let host = String(knownHostPattern[knownHostPattern.index(after: knownHostPattern.startIndex)..<closingBracket])
            let portStart = knownHostPattern.index(closingBracket, offsetBy: 2)
            guard !host.isEmpty, UInt16(knownHostPattern[portStart...]) != nil else {
                return nil
            }
            return "\(host):\(knownHostPattern[portStart...])"
        }

        guard !knownHostPattern.contains("*"), !knownHostPattern.contains("?") else {
            return nil
        }
        return "\(knownHostPattern):22"
    }
}

private struct KnownHostEntry {
    var hosts: [String]
    var publicKey: String

    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
            return nil
        }

        let fields = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        let keyOffset = fields.first?.hasPrefix("@") == true ? 1 : 0
        guard fields.count >= keyOffset + 3 else {
            return nil
        }

        let hostField = fields[keyOffset]
        guard !hostField.hasPrefix("|") else {
            return nil
        }

        hosts = hostField.split(separator: ",").map(String.init)
        publicKey = "\(fields[keyOffset + 1]) \(fields[keyOffset + 2])"
    }
}
