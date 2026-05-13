import Testing
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
