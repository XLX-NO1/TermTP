import Testing
import TermCCore
@testable import TermCApp

@MainActor
@Test func menuBarTemplateImageFallsBackWhenResourceIsMissing() {
    let image = MenuBarController.makeMenuBarTemplateImage()

    #expect(image.size == .init(width: 18, height: 18))
    #expect(image.isTemplate)
}

@Test func saveDraftConnectionRejectsPortZero() {
    let state = AppState(connections: [])
    state.draftHost = "example.com"
    state.draftPort = "0"
    state.draftUsername = "me"

    state.saveDraftConnection()

    #expect(state.connections.isEmpty)
}

@Test func saveDraftConnectionRejectsEmptyPrivateKeyPath() {
    let state = AppState(connections: [])
    state.draftHost = "example.com"
    state.draftPort = "22"
    state.draftUsername = "me"
    state.draftUsesKey = true
    state.draftPrivateKeyPath = " \n "

    state.saveDraftConnection()

    #expect(state.connections.isEmpty)
}

@Test func refreshRemoteFilesListsArchiveAndLogsUnderCurrentRemotePath() {
    let state = AppState()
    state.remotePath = "/srv/app"

    state.refreshRemoteFiles()

    #expect(state.remoteFiles == [
        RemoteFile(name: "app.tar.gz", path: "/srv/app/app.tar.gz", kind: .file, size: 2048),
        RemoteFile(name: "logs", path: "/srv/app/logs", kind: .directory, size: 0)
    ])
}
