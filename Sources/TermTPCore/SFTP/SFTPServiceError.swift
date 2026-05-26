import Foundation

public enum SFTPServiceError: Error, Equatable {
    case notFound(String)
    case unsupportedSession
}
