import AppKit
import SwiftUI
import TermTPCore

struct ConnectionSidebarView: View {
    @Bindable var state: AppState
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []

    private var filteredConnections: [ConnectionRecord] {
        guard !searchText.isEmpty else {
            return state.connections
        }

        return state.connections.filter { connection in
                connection.alias.localizedCaseInsensitiveContains(searchText)
                    || connection.host.localizedCaseInsensitiveContains(searchText)
                    || connection.username.localizedCaseInsensitiveContains(searchText)
                    || (connection.group?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || connection.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var favorites: [ConnectionRecord] {
        filteredConnections.filter { favoriteIDs.contains($0.id) }
    }

    private var history: [ConnectionRecord] {
        filteredConnections.filter { historyIDs.contains($0.id) }
    }

    private var favoriteIDs: Set<ConnectionRecord.ID> {
        Set(state.favoriteConnections.map(\.id))
    }

    private var historyIDs: Set<ConnectionRecord.ID> {
        Set(state.historyConnections.map(\.id))
    }

    private enum ConnectionSectionKind {
        case favorites
        case history
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

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: ConnectionSidebarLayout.sectionSpacing) {
                    connectionSection(state.t.favorites, connections: favorites, kind: .favorites)

                    connectionSection(state.t.history, connections: history, kind: .history)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)

            Spacer(minLength: 0)

            VStack(spacing: ConnectionSidebarLayout.footerSpacing) {
                HStack(spacing: 6) {
                    Button {
                        importConnections()
                    } label: {
                        Label(state.t.importConnections, systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(ConnectionSidebarActionStyle())
                    .controlSize(.small)

                    Button {
                        exportConnections()
                    } label: {
                        Label(state.t.exportConnections, systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ConnectionSidebarActionStyle())
                    .controlSize(.small)
                }

                Button {
                    state.clearHistory()
                } label: {
                    Text(state.t.clearHistory)
                }
                .buttonStyle(ConnectionSidebarActionStyle(alignment: .leading))
            }
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
        kind: ConnectionSectionKind
    ) -> some View {
        let sectionID = "\(kind)-\(title)"
        let isExpanded = expandedSections.contains(sectionID)

        return VStack(alignment: .leading, spacing: 4) {
            Button {
                toggleSection(sectionID)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 10)

                    Text(title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .textCase(.uppercase)

                    Spacer(minLength: 0)

                    Text("\(connections.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.48))
                }
                .frame(height: ConnectionSidebarLayout.collapsibleHeaderHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isExpanded {
                EmptyView()
            } else if connections.isEmpty {
                emptySection
            } else {
                connectionRows(connections, kind: kind)
            }
        }
    }

    private var emptySection: some View {
        Text(state.t.noConnections)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.66))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
    }

    private func connectionRows(_ connections: [ConnectionRecord], kind: ConnectionSectionKind) -> some View {
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
                    deleteConnection(connection.id, from: kind)
                }
            }
        }
    }

    private func toggleSection(_ id: String) {
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }

    private func deleteConnection(_ id: ConnectionRecord.ID, from kind: ConnectionSectionKind) {
        switch kind {
        case .favorites:
            state.deleteFavoriteConnection(id)
        case .history:
            state.deleteHistoryConnection(id)
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
                state.showNotification(kind: .error, message: state.t.importConnectionsFailed(String(describing: error)))
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
            state.showNotification(kind: .error, message: state.t.exportConnectionsFailed(String(describing: error)))
        }
    }
}

enum ConnectionSidebarLayout {
    static let sectionSpacing: CGFloat = 5
    static let footerSpacing: CGFloat = 7
    static let collapsibleHeaderHeight: CGFloat = 18
    static let primarySectionCount = 2
    static let startsCollapsed = true
}

struct ConnectionSidebarActionStyle: ButtonStyle {
    static let textOpacity = 0.92
    static let backgroundOpacity = 0.07
    static let pressedBackgroundOpacity = 0.13
    static let borderOpacity = 0.12
    static let cornerRadius: CGFloat = 6

    var alignment: Alignment = .center

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.white.opacity(Self.textOpacity))
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Color.white.opacity(
                    configuration.isPressed ? Self.pressedBackgroundOpacity : Self.backgroundOpacity
                ),
                in: RoundedRectangle(cornerRadius: Self.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .stroke(Color.white.opacity(Self.borderOpacity), lineWidth: 1)
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

            if let group = connection.group, !group.isEmpty {
                Text(group)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
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
