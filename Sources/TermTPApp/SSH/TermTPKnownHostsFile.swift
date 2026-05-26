import Foundation

enum TermTPKnownHostsFile {
    static var defaultFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TermTP", isDirectory: true)
            .appendingPathComponent("known_hosts")
    }

    static func removeEntry(host: String, port: UInt16, from fileURL: URL = defaultFileURL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let hostPatterns = Set([
            host,
            "[\(host)]:\(port)"
        ])
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
}
