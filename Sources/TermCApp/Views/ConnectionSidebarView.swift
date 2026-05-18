import AppKit
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
            Text(state.t.connections)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Button {
                state.beginNewConnection()
            } label: {
                Label(state.t.newConnection, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField(state.t.search, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            if searchText.isEmpty {
                connectionSection(state.t.recent, connections: state.recentConnections, isHistory: false)
            }

            connectionSection(state.t.favorites, connections: favorites, isHistory: false)

            if searchText.isEmpty {
                ForEach(state.connectionTags, id: \.self) { tag in
                    connectionSection(
                        "#\(tag)",
                        connections: state.connections.filter { $0.tags.contains(tag) },
                        isHistory: false
                    )
                }
            }

            connectionSection(state.t.history, connections: history, isHistory: true)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button {
                    importConnections()
                } label: {
                    Label(state.t.importConnections, systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    exportConnections()
                } label: {
                    Label(state.t.exportConnections, systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                state.clearHistory()
            } label: {
                Text(state.t.clearHistory)
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
                Text(state.t.noConnections)
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
                        Button(connection.isFavorite ? state.t.removeFromFavorites : state.t.addToFavorites) {
                            state.toggleFavorite(connection.id)
                        }

                        Button(state.t.delete, role: .destructive) {
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

    private func importConnections() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            do {
                let data = try Data(contentsOf: url)
                try await state.importConnections(from: data)
            } catch {
                NSSound.beep()
            }
        }
    }

    private func exportConnections() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "termtp-connections.json"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try state.exportConnections()
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
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
