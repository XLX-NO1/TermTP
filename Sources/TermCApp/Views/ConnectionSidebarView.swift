import SwiftUI
import TermCCore

struct ConnectionSidebarView: View {
    @Bindable var state: AppState
    @State private var searchText = ""

    private var filteredConnections: [ConnectionRecord] {
        guard !searchText.isEmpty else {
            return state.connections
        }

        return state.connections.filter { connection in
            connection.alias.localizedCaseInsensitiveContains(searchText)
                || connection.host.localizedCaseInsensitiveContains(searchText)
                || connection.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var favorites: [ConnectionRecord] {
        filteredConnections.filter(\.isFavorite)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Connections")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Button {
                state.beginNewConnection()
            } label: {
                Label("New Connection", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            connectionSection("Favorites", connections: favorites)

            connectionSection("History", connections: filteredConnections)

            Spacer(minLength: 0)

            Button("Clear History") {}
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.10, green: 0.11, blue: 0.12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    private func connectionSection(_ title: String, connections: [ConnectionRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .textCase(.uppercase)

            if connections.isEmpty {
                Text("No connections")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
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
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(connection.username)@\(connection.host):\(connection.port)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    ConnectionSidebarView(state: AppState())
        .frame(width: AppLayout.connectionSidebarWidth, height: 460)
}
