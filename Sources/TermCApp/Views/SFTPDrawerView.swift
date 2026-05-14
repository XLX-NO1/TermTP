import SwiftUI
import TermCCore

struct SFTPDrawerView: View {
    @Bindable var state: AppState
    @State private var selectedRemoteFile: RemoteFile?
    @State private var pathInput = ""

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
                .help("Refresh")
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
                .help("Parent Directory")

                TextField("Remote path", text: $pathInput)
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
                        Button("Upload Here") {
                            chooseUploadFile()
                        }

                        Button("Refresh") {
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
                    Button("Upload Here") {
                        chooseUploadFile()
                    }

                    Button("Refresh") {
                        Task {
                            await state.refreshRemoteFiles()
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if !visibleTransfers.isEmpty {
                transferList
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.12, green: 0.13, blue: 0.15))
        .contextMenu {
            Button("Upload Here") {
                chooseUploadFile()
            }

            Button("Refresh") {
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
    }

    private var transferList: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(visibleTransfers.suffix(3)) { transfer in
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
                    }

                    ProgressView(value: transferProgress(for: transfer))
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                }
            }
        }
    }

    private var visibleTransfers: [TransferRecord] {
        state.transfers.filter { $0.state != .completed }
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
                Button("Open") {
                    Task {
                        await state.openRemoteDirectory(file)
                    }
                }

                Button("Upload Here") {
                    chooseUploadFile(to: file)
                }
            } else {
                Button("Download") {
                    chooseDownloadLocation(for: file)
                }
            }
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

    private func transferProgress(for transfer: TransferRecord) -> Double {
        guard transfer.totalBytes > 0 else {
            return transfer.state == .completed ? 1 : 0
        }

        return min(1, max(0, Double(transfer.bytesCompleted) / Double(transfer.totalBytes)))
    }

    private func transferLabel(for transfer: TransferRecord) -> String {
        switch transfer.state {
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        case .queued:
            return "Queued"
        case .running:
            if transfer.totalBytes > 0 {
                let completed = ByteCountFormatter.string(fromByteCount: transfer.bytesCompleted, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: transfer.totalBytes, countStyle: .file)
                return "\(completed) / \(total)"
            }
            return "Running"
        }
    }
}

#Preview {
    SFTPDrawerView(state: AppState())
        .frame(width: 720, height: AppLayout.transferDrawerHeight)
}
