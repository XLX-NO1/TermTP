import Foundation

public extension ConnectionRecord {
    static let samplePassword = ConnectionRecord(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        alias: "Local",
        host: "localhost",
        port: 22,
        username: "me",
        authentication: .password,
        tags: ["dev"],
        isFavorite: false,
        lastConnectedAt: nil,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )
}
