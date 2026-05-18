import Testing
@testable import TermCApp

@Test func appLanguageDefaultsToChinese() {
    #expect(AppLanguage.default == .zhHans)
}

@Test func appLanguageIncludesCommonLanguages() {
    #expect(AppLanguage.allCases.map(\.rawValue) == [
        "zh-Hans",
        "en",
        "ja",
        "ko",
        "es",
        "fr",
        "de",
        "ru",
        "pt"
    ])
}

@Test func localizedStringsReturnChineseAndEnglishValues() {
    #expect(AppStrings(language: .zhHans).newConnection == "新建连接")
    #expect(AppStrings(language: .en).newConnection == "New Connection")
    #expect(AppStrings(language: .zhHans).settings == "设置")
    #expect(AppStrings(language: .en).settings == "Settings")
}

@MainActor
@Test func appStateLanguageCanBeChanged() {
    let state = AppState(connections: [], language: .zhHans)

    state.language = .en

    #expect(state.language == .en)
    #expect(state.t.cancel == "Cancel")
}
