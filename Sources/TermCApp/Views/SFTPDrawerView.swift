import SwiftUI
import TermCCore

struct SFTPDrawerView: View {
    @Bindable var state: AppState
    @State var selectedRemoteFile: RemoteFile?
    @State private var pathInput = ""
    @State var namePrompt: SFTPNamePrompt?
    @State var pendingName = ""
    @State var permissionsPrompt: RemoteFile?
    @State var pendingPermissions = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SFTP")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                if state.selectedSFTPCredentialConnection != nil {
                    Button {
                        Task {
                            await state.connectSFTPForSelectedTab()
                        }
                    } label: {
                        Label(state.t.connectSFTP, systemImage: "link")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(.white)
                    .help(state.t.connectSFTP)
                }

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
                        SFTPFileRowView(
                            state: state,
                            file: file,
                            selectedRemoteFile: $selectedRemoteFile,
                            chooseUploadFile: { chooseUploadFile(to: $0) },
                            chooseDownloadLocation: { chooseDownloadLocation(for: $0) },
                            showRenamePrompt: { showRenamePrompt(for: $0) },
                            showPermissionsPrompt: { showPermissionsPrompt(for: $0) }
                        )
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
                SFTPTransferListView(state: state)
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
}

#Preview {
    SFTPDrawerView(state: AppState())
        .frame(width: 720, height: AppLayout.transferDrawerHeight)
}
