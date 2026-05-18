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
                || connection.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var favorites: [ConnectionRecord] {
        filteredConnections.filter { state.favoriteConnections.contains($0) }
    }

    private var history: [ConnectionRecord] {
        filteredConnections.filter { state.historyConnections.contains($0) }
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

            if searchText.isEmpty {
                connectionSection("Recent", connections: state.recentConnections, isHistory: false)
            }

            connectionSection("Favorites", connections: favorites, isHistory: false)

            if searchText.isEmpty {
                ForEach(state.connectionTags, id: \.self) { tag in
                    connectionSection(
                        "#\(tag)",
                        connections: state.connections.filter { $0.tags.contains(tag) },
                        isHistory: false
                    )
                }
            }

            connectionSection("History", connections: history, isHistory: true)

            Spacer(minLength: 0)

            Button {
                state.clearHistory()
            } label: {
                Text("Clear History")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
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

    private func connectionSection(
        _ title: String,
        connections: [ConnectionRecord],
        isHistory: Bool
    ) -> some View {
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
                    Button {
                        Task {
                            await state.connect(connection)
                        }
                    } label: {
                        ConnectionRow(connection: connection)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(connection.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                            state.toggleFavorite(connection.id)
                        }

                        Button("Delete", role: .destructive) {
                            if isHistory {
                                state.deleteHistoryConnection(connection.id)
                            } else {
                                state.deleteConnection(connection.id)
                            }
                        }
                    }
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

            if !connection.tags.isEmpty {
                Text(connection.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption2)
                    .foregroundStyle(Color.green.opacity(0.72))
                    .lineLimit(1)
            }
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
