import Foundation
import TermTPCore

enum SFTPNamePrompt: Identifiable {
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
