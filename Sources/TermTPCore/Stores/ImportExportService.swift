import Foundation

public struct ImportExportService: Sendable {
    public init() {}

    public func export(_ records: [ConnectionRecord]) throws -> Data {
        let payload = ExportPayload(version: 1, connections: records)
        return try JSONEncoder.termtp.encode(payload)
    }

    public func `import`(_ data: Data) throws -> [ConnectionRecord] {
        let payload = try JSONDecoder.termtp.decode(ExportPayload.self, from: data)
        var seen: Set<String> = []
        return payload.connections.filter { record in
            let key = "\(record.host):\(record.port):\(record.username):\(record.alias)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}

private struct ExportPayload: Codable {
    var version: Int
    var connections: [ConnectionRecord]
}
