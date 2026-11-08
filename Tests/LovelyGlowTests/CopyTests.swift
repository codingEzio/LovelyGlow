import Testing
@testable import LovelyGlowCore

struct CopyTests {
    @Test func everyConcreteLanguageHasEveryKey() {
        let languages: [AppLanguage] = [.en, .zhHant, .zhHans, .ko, .ja, .es, .ru, .uk]
        for language in languages {
            for key in CopyKey.allCases {
                let value = CopyCatalog.text(key, language: language)
                #expect(!value.isEmpty, "\(language.rawValue) \(key.rawValue)")
            }
        }
    }

    @Test func autoPrefersTraditionalChineseForTaiwan() {
        #expect(CopyCatalog.resolvedLanguage(.auto, preferred: ["zh-Hant-TW"]) == .zhHant)
        #expect(CopyCatalog.resolvedLanguage(.auto, preferred: ["ja-JP", "en"]) == .ja)
        #expect(CopyCatalog.text(.menuEnableGlow, language: .auto, preferred: ["zh-Hant-TW"]) == "啟用光暈")
    }
}
