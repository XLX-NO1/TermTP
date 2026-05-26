import Foundation

extension AppState {
    func joinedRemotePath(directory: String, name: String) -> String {
        let trimmedDirectory = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDirectory.isEmpty || trimmedDirectory == "." {
            return name
        }

        if trimmedDirectory == "/" {
            return "/\(name)"
        }

        var normalizedDirectory = trimmedDirectory
        while normalizedDirectory.hasSuffix("/") {
            normalizedDirectory.removeLast()
        }
        return "\(normalizedDirectory)/\(name)"
    }
}
