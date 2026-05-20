import SwiftUI
import TermCCore

struct SFTPFileRowView: View {
    @Bindable var state: AppState
    let file: RemoteFile
    @Binding var selectedRemoteFile: RemoteFile?
    let chooseUploadFile: (RemoteFile?) -> Void
    let chooseDownloadLocation: (RemoteFile) -> Void
    let showRenamePrompt: (RemoteFile) -> Void
    let showPermissionsPrompt: (RemoteFile) -> Void

    var body: some View {
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
                    chooseUploadFile(file)
                }
            } else {
                Button(state.t.preview) {
                    Task {
                        await state.previewRemoteFile(file)
                    }
                }

                Button(state.t.download) {
                    chooseDownloadLocation(file)
                }
            }

            Button(state.t.changePermissions) {
                showPermissionsPrompt(file)
            }

            Button(state.t.rename) {
                showRenamePrompt(file)
            }

            Button(state.t.delete, role: .destructive) {
                Task {
                    await state.deleteRemoteFile(file)
                }
            }
        }
    }
}
