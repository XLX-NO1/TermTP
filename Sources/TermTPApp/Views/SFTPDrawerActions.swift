import SwiftUI
import TermTPCore
import UniformTypeIdentifiers

extension SFTPDrawerView {
    func showCreateDirectoryPrompt() {
        pendingName = ""
        namePrompt = .createDirectory
    }

    func showRenamePrompt(for file: RemoteFile) {
        pendingName = file.name
        namePrompt = .rename(file)
    }

    func showPermissionsPrompt(for file: RemoteFile) {
        pendingPermissions = file.permissions.map { String($0, radix: 8) } ?? ""
        permissionsPrompt = file
    }

    func submitNamePrompt(_ prompt: SFTPNamePrompt) {
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

    func submitPermissionsPrompt(for file: RemoteFile) {
        let mode = pendingPermissions
        permissionsPrompt = nil
        Task {
            await state.changeRemoteFilePermissions(file, modeText: mode)
        }
    }

    func chooseUploadFile(to directory: RemoteFile? = nil) {
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

    func chooseDownloadLocation(for selectedRemoteFile: RemoteFile) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = URL(fileURLWithPath: selectedRemoteFile.path).lastPathComponent

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await state.downloadFile(remoteFile: selectedRemoteFile, localPath: url.path)
        }
    }

    func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
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
}
