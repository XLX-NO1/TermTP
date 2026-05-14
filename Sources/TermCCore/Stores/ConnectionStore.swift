import Foundation

public struct ConnectionSnapshot: Equatable, Sendable {
    public var connections: [ConnectionRecord]
    public var history: [HistoryRecord]

    public var favorites: [ConnectionRecord] {
        connections.filter(\.isFavorite)
    }
}

public actor ConnectionStore {
    private struct DiskState: Codable {
        var connections: [ConnectionRecord]
        var history: [HistoryRecord]
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> ConnectionSnapshot {
        let state = try readState()
        return ConnectionSnapshot(connections: state.connections, history: state.history)
    }

    public func upsert(_ record: ConnectionRecord) throws {
        var state = try readState()
        if let index = state.connections.firstIndex(where: { $0.id == record.id }) {
            state.connections[index] = record
        } else {
            state.connections.append(record)
        }
        try writeState(state)
    }

    public func replaceConnections(_ connections: [ConnectionRecord]) throws {
        var state = try readState()
        let ids = Set(connections.map(\.id))
        state.connections = connections
        state.history.removeAll { !ids.contains($0.connectionID) }
        try writeState(state)
    }

    public func delete(id: UUID) throws {
        var state = try readState()
        state.connections.removeAll { $0.id == id }
        state.history.removeAll { $0.connectionID == id }
        try writeState(state)
    }

    public func addHistory(_ record: HistoryRecord) throws {
        var state = try readState()
        state.history.insert(record, at: 0)
        state.history = Array(state.history.prefix(100))
        try writeState(state)
    }

    public func clearHistory() throws {
        var state = try readState()
        state.history.removeAll()
        try writeState(state)
    }

    private func readState() throws -> DiskState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return DiskState(connections: [], history: [])
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.termc.decode(DiskState.self, from: data)
    }

    private func writeState(_ state: DiskState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.termc.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}
