import SwiftUI
import TermCCore

struct ConnectionSidebarView: View {
    let connections: [ConnectionRecord]
    @State private var searchText = ""

    private var filteredConnections: [ConnectionRecord] {
        guard !searchText.isEmpty else {
            return connections
        }

        return connections.filter { connection in
            connection.alias.localizedCaseInsensitiveContains(searchText)
                || connection.host.localizedCaseInsensitiveContains(searchText)
                || connection.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var favorites: [ConnectionRecord] {
        filteredConnections.filter(\.isFavorite)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connections")
                .font(.headline)
                .foregroundStyle(.white)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)

            connectionSection("Favorites", connections: favorites)

            connectionSection("History", connections: filteredConnections)

            Spacer(minLength: 0)

            Button("Clear History") {}
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.13, green: 0.14, blue: 0.16))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    private func connectionSection(_ title: String, connections: [ConnectionRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if connections.isEmpty {
                Text("No connections")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(connections) { connection in
                    ConnectionRow(connection: connection)
                }
            }
        }
    }
}

private struct ConnectionRow: View {
    let connection: ConnectionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(connection.alias)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(connection.username)@\(connection.host):\(connection.port)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ConnectionSidebarView(connections: [.samplePassword])
        .frame(width: 260, height: 640)
}
