import Foundation

extension AppState {
    func downloadWorkingPath(for destinationPath: String) -> String {
        destinationPath + ".termtp-download"
    }

    func finalizeDownload(workingPath: String, destinationPath: String) throws {
        let fileManager = FileManager.default
        let workingURL = URL(fileURLWithPath: workingPath)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        if fileManager.fileExists(atPath: destinationPath) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: workingURL)
        } else {
            try fileManager.moveItem(at: workingURL, to: destinationURL)
        }
    }

    func localFileSize(at path: String) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.size] as? Int64 ?? 0
    }
}
