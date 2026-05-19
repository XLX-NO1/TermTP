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

@Test func allLocalizedDictionariesHaveRequiredKnownNonEmptyKeys() {
    for language in AppLanguage.allCases {
        let keys = AppStrings.keys(for: language)

        #expect(keys.isSubset(of: AppStrings.requiredKeys))
        #expect(keys == AppStrings.requiredKeys)

        for key in keys {
            #expect(!AppStrings.rawValue(for: key, language: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

@Test func nonEnglishLanguagesDoNotLeaveCommonInterfaceStringsInEnglish() {
    let englishValues = AppStrings.commonInterfaceKeys.reduce(into: [String: String]()) { values, key in
        values[key] = AppStrings.rawValue(for: key, language: .en)
    }

    for language in AppLanguage.allCases where language != .en {
        for key in AppStrings.commonInterfaceKeys {
            #expect(
                AppStrings.rawValue(for: key, language: language) != englishValues[key],
                "\(language.rawValue) still uses English for \(key)"
            )
        }
    }
}

@Test func localizedTechnicalTermsUsePolishedNativeWording() {
    #expect(AppStrings(language: .ja).terminalTheme == "ターミナルテーマ")
    #expect(AppStrings(language: .ja).defaultRemotePath == "デフォルトのリモートパス")
    #expect(AppStrings(language: .ja).processMonitor == "プロセスモニター")

    #expect(AppStrings(language: .ko).privateKeyPassphrase == "개인 키 암호")
    #expect(AppStrings(language: .ko).portForwarding == "포트 포워딩")
    #expect(AppStrings(language: .ko).aliveMaxCount == "연결 유지 최대 횟수")

    #expect(AppStrings(language: .es).jumpHost == "Servidor de salto")
    #expect(AppStrings(language: .es).aliveMaxCount == "Reintentos de keepalive")
    #expect(AppStrings(language: .es).bindAddress == "Dirección de escucha")

    #expect(AppStrings(language: .fr).jumpHost == "Hôte bastion")
    #expect(AppStrings(language: .fr).aliveIntervalSeconds == "Intervalle keepalive (s)")
    #expect(AppStrings(language: .fr).aliveMaxCount == "Nombre maximal de keepalive")

    #expect(AppStrings(language: .de).terminalTheme == "Terminal-Design")
    #expect(AppStrings(language: .de).toggleSFTPDrawer == "SFTP-Bereich ein-/ausblenden")
    #expect(AppStrings(language: .de).failedToConnect == "Keine Verbindung zu")

    #expect(AppStrings(language: .ru).portForwarding == "Перенаправление портов")
    #expect(AppStrings(language: .ru).bindAddress == "Адрес прослушивания")
    #expect(AppStrings(language: .ru).privateKeyPassphrase == "Парольная фраза ключа")

    #expect(AppStrings(language: .pt).privateKeyPassphrase == "Frase secreta da chave")
    #expect(AppStrings(language: .pt).bindAddress == "Endereço de escuta")
    #expect(AppStrings(language: .pt).jumpHost == "Servidor de salto")
}

@MainActor
@Test func appStateLanguageCanBeChanged() {
    let state = AppState(connections: [], language: .zhHans)

    state.language = .en

    #expect(state.language == .en)
    #expect(state.t.cancel == "Cancel")
}

@MainActor
@Test func terminalThemeDefaultsToClassicGreenAndCanBeChanged() {
    let state = AppState(connections: [], terminalTheme: .classicGreen)

    state.terminalTheme = .amber

    #expect(TerminalTheme.default == .classicGreen)
    #expect(TerminalTheme.allCases.map(\.rawValue) == [
        "classicGreen",
        "amber",
        "paperWhite",
        "ocean"
    ])
    #expect(state.terminalTheme == .amber)
    #expect(state.terminalPalette.foreground.red > state.terminalPalette.foreground.green)
}
