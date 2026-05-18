import SwiftUI
import TermCCore
import UniformTypeIdentifiers

struct SFTPDrawerView: View {
    @Bindable var state: AppState
    @State private var selectedRemoteFile: RemoteFile?
    @State private var pathInput = ""
    @State private var namePrompt: NamePrompt?
    @State private var pendingName = ""
    @State private var permissionsPrompt: RemoteFile?
    @State private var pendingPermissions = ""

    private enum NamePrompt: Identifiable {
        case createDirectory
        case rename(RemoteFile)

        var id: String {
            switch self {
            case .createDirectory:
                return "createDirectory"
            case .rename(let file):
                return "rename-\(file.id)"
            }
        }

        func title(_ strings: AppStrings) -> String {
            switch self {
            case .createDirectory:
                return strings.newFolder
            case .rename:
                return strings.rename
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SFTP")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    Task {
                        await state.refreshRemoteFiles()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(state.t.refresh)
            }

            HStack(spacing: 6) {
                Button {
                    Task {
                        await state.openRemoteParentDirectory()
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(state.remotePath == "." || state.remotePath == "/" ? .white.opacity(0.28) : .white)
                .disabled(state.remotePath == "." || state.remotePath == "/")
                .help(state.t.parentDirectory)

                TextField(state.t.remotePath, text: $pathInput)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 6))
                    .onSubmit {
                        Task {
                            await state.openRemotePath(pathInput)
                            pathInput = state.remotePath
                        }
                    }
                    .onAppear {
                        pathInput = state.remotePath
                    }
                    .onChange(of: state.remotePath) { _, newValue in
                        pathInput = newValue
                    }
                    .contextMenu {
                        Button(state.t.uploadHere) {
                            chooseUploadFile()
                        }

                        Button(state.t.newFolder) {
                            showCreateDirectoryPrompt()
                        }

                        Button(state.t.refresh) {
                            Task {
                                await state.refreshRemoteFiles()
                            }
                        }
                    }
            }

            ScrollView(.vertical) {
                LazyVStack(spacing: 5) {
                    ForEach(state.remoteFiles) { file in
                        fileRow(file)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contextMenu {
                    Button(state.t.uploadHere) {
                        chooseUploadFile()
                    }

                    Button(state.t.newFolder) {
                        showCreateDirectoryPrompt()
                    }

                    Button(state.t.refresh) {
                        Task {
                            await state.refreshRemoteFiles()
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDroppedFiles(providers)
            }

            Spacer(minLength: 0)

            if !state.visibleTransfers.isEmpty {
                transferList
                    .transition(.opacity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.12, green: 0.13, blue: 0.15))
        .contextMenu {
            Button(state.t.uploadHere) {
                chooseUploadFile()
            }

            Button(state.t.newFolder) {
                showCreateDirectoryPrompt()
            }

            Button(state.t.refresh) {
                Task {
                    await state.refreshRemoteFiles()
                }
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .sheet(item: $namePrompt) { prompt in
            VStack(alignment: .leading, spacing: 14) {
                Text(prompt.title(state.t))
                    .font(.headline)

                TextField(state.t.name, text: $pendingName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()

                    Button(state.t.cancel, role: .cancel) {
                        namePrompt = nil
                    }

                    Button(state.t.ok) {
                        submitNamePrompt(prompt)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(pendingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
        .sheet(item: $permissionsPrompt) { file in
            VStack(alignment: .leading, spacing: 14) {
                Text(state.t.changePermissions)
                    .font(.headline)

                Text(file.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                TextField(state.t.permissions, text: $pendingPermissions)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()

                    Button(state.t.cancel, role: .cancel) {
                        permissionsPrompt = nil
                    }

                    Button(state.t.ok) {
                        submitPermissionsPrompt(for: file)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(pendingPermissions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
        .sheet(item: Binding(
            get: { state.filePreview },
            set: { preview in
                if preview == nil {
                    state.dismissFilePreview()
                }
            }
        )) { preview in
            VStack(alignment: .leading, spacing: 12) {
                Text(preview.file.name)
                    .font(.headline)

                ScrollView {
                    Text(preview.text)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                }
                .frame(width: 620, height: 420)
                .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(20)
        }
    }

    private var transferList: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(state.t.transfers)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Button {
                    state.clearFinishedTransfersForSelectedTab()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.68))
                .help(state.t.clearFinishedTransfers)
            }

            ForEach(state.visibleTransfers.suffix(3)) { transfer in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: transfer.direction == .download ? "arrow.down.circle" : "arrow.up.circle")
                            .foregroundStyle(.white.opacity(0.72))

                        Text(URL(fileURLWithPath: transfer.direction == .download ? transfer.remotePath : transfer.localPath).lastPathComponent)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        Text(transferLabel(for: transfer))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))

                        transferActions(for: transfer)
                    }

                    ProgressView(value: transferProgress(for: transfer))
                        .progressViewStyle(.linear)
                        .controlSize(.small)

                    if transfer.state == .failed, let errorMessage = transfer.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.82))
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func transferActions(for transfer: TransferRecord) -> some View {
        switch transfer.state {
        case .running, .queued:
            Button {
                state.cancelTransfer(transfer.id)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.74))
            .help(state.t.cancel)
        case .failed, .cancelled:
            Button {
                Task {
                    await state.retryTransfer(transfer.id)
                }
            } label: {
                Image(systemName: "arrow.clockwise.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.74))
            .help(state.t.retry)
        case .completed:
            EmptyView()
        }
    }

    private func fileRow(_ file: RemoteFile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: file.kind == .file ? "doc" : "folder")
                .foregroundStyle(file.kind == .directory ? Color.green.opacity(0.82) : Color.white.opacity(0.70))
                .frame(width: 14)

            Text(file.name)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if file.kind == .file {
                Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                    .foregroundStyle(.white.opacity(0.62))
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            selectedRemoteFile == file ? Color.white.opacity(0.13) : Color.white.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .onTapGesture {
            selectedRemoteFile = file
        }
        .onTapGesture(count: 2) {
            Task {
                await state.openRemoteDirectory(file)
            }
        }
        .contextMenu {
            if file.kind == .directory {
                Button(state.t.open) {
                    Task {
                        await state.openRemoteDirectory(file)
                    }
                }

                Button(state.t.uploadHere) {
                    chooseUploadFile(to: file)
                }
            } else {
                Button(state.t.preview) {
                    Task {
                        await state.previewRemoteFile(file)
                    }
                }

                Button(state.t.download) {
                    chooseDownloadLocation(for: file)
                }
            }

            Button(state.t.changePermissions) {
                showPermissionsPrompt(for: file)
            }

            Button(state.t.rename) {
                showRenamePrompt(for: file)
            }

            Button(state.t.delete, role: .destructive) {
                Task {
                    await state.deleteRemoteFile(file)
                }
            }
        }
    }

    private func showCreateDirectoryPrompt() {
        pendingName = ""
        namePrompt = .createDirectory
    }

    private func showRenamePrompt(for file: RemoteFile) {
        pendingName = file.name
        namePrompt = .rename(file)
    }

    private func showPermissionsPrompt(for file: RemoteFile) {
        pendingPermissions = file.permissions.map { String($0, radix: 8) } ?? ""
        permissionsPrompt = file
    }

    private func submitNamePrompt(_ prompt: NamePrompt) {
        let name = pendingName
        namePrompt = nil
        Task {
            switch prompt {
            case .createDirectory:
                await state.createRemoteDirectory(named: name)
            case .rename(let file):
                await state.renameRemoteFile(file, to: name)
            }
        }
    }

    private func submitPermissionsPrompt(for file: RemoteFile) {
        let mode = pendingPermissions
        permissionsPrompt = nil
        Task {
            await state.changeRemoteFilePermissions(file, modeText: mode)
        }
    }

    private func chooseUploadFile(to directory: RemoteFile? = nil) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            if let directory {
                await state.uploadFile(localPath: url.path, toRemoteDirectory: directory)
            } else {
                await state.uploadFile(localPath: url.path)
            }
        }
    }

    private func chooseDownloadLocation(for selectedRemoteFile: RemoteFile) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = URL(fileURLWithPath: selectedRemoteFile.path).lastPathComponent

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await state.downloadFile(remoteFile: selectedRemoteFile, localPath: url.path)
        }
    }

    private func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        var didStartUpload = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            didStartUpload = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                guard let url else {
                    return
                }

                Task { @MainActor in
                    await state.uploadFile(localPath: url.path)
                }
            }
        }

        return didStartUpload
    }

    private func transferProgress(for transfer: TransferRecord) -> Double {
        guard transfer.totalBytes > 0 else {
            return transfer.state == .completed ? 1 : 0
        }

        return min(1, max(0, Double(transfer.bytesCompleted) / Double(transfer.totalBytes)))
    }

    private func transferLabel(for transfer: TransferRecord) -> String {
        switch transfer.state {
        case .completed:
            return state.t.done
        case .failed:
            return state.t.failed
        case .cancelled:
            return state.t.cancelled
        case .queued:
            return state.t.queued
        case .running:
            if transfer.totalBytes > 0 {
                let completed = ByteCountFormatter.string(fromByteCount: transfer.bytesCompleted, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: transfer.totalBytes, countStyle: .file)
                var parts = ["\(completed) / \(total)"]
                if transfer.bytesPerSecond > 0 {
                    parts.append(ByteCountFormatter.string(fromByteCount: Int64(transfer.bytesPerSecond), countStyle: .file) + "/s")
                }
                if let remaining = transfer.estimatedSecondsRemaining {
                    parts.append(formatRemainingTime(remaining))
                }
                return parts.joined(separator: "  ")
            }
            return state.t.running
        }
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.up)))
        if totalSeconds < 60 {
            return state.t.secondsRemaining(totalSeconds)
        }

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return state.t.minutesSecondsRemaining(minutes, seconds)
    }
}

#Preview {
    SFTPDrawerView(state: AppState())
        .frame(width: 720, height: AppLayout.transferDrawerHeight)
}
