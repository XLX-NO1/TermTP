import Foundation
import TermTPCore

extension AppState {
    func importKey(for connection: ConnectionRecord) -> String {
        "\(connection.host):\(connection.port):\(connection.username):\(connection.alias)"
    }

    func markConnectionConnected(_ connection: ConnectionRecord) -> ConnectionRecord {
        var connection = connection
        connection.lastConnectedAt = Date()
        connection.updatedAt = Date()

        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        }

        Task {
            await persistConnections()
        }
        return connection
    }
}
