import XCTest
@testable import AeroPulseLocalization

final class LanguageManagerTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "LanguageManagerTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        if let suiteName = suiteName, let userDefaults = userDefaults {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultSelectionIsSystem() {
        let manager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { ["en-US"] }
        )

        XCTAssertEqual(manager.selectedLanguage, .system)
        XCTAssertEqual(manager.effectiveLanguage, .en)
    }

    func testEffectiveLanguageWhenPreferredLanguagesStartsWithZh() {
        let manager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { ["zh-Hans-CN", "en-US"] }
        )

        XCTAssertEqual(manager.selectedLanguage, .system)
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)
    }

    func testEffectiveLanguageWhenPreferredLanguagesStartsWithEnOrOther() {
        let englishManager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { ["en-US"] }
        )
        XCTAssertEqual(englishManager.selectedLanguage, .system)
        XCTAssertEqual(englishManager.effectiveLanguage, .en)

        let japaneseManager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { ["ja-JP"] }
        )
        XCTAssertEqual(japaneseManager.selectedLanguage, .system)
        XCTAssertEqual(japaneseManager.effectiveLanguage, .en)

        let emptyManager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { [] }
        )
        XCTAssertEqual(emptyManager.selectedLanguage, .system)
        XCTAssertEqual(emptyManager.effectiveLanguage, .en)
    }

    func testSetLanguageEnPersistsAndUpdatesEffectiveLanguage() {
        let manager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { ["zh-CN"] }
        )
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)

        manager.setLanguage(.en)

        XCTAssertEqual(manager.selectedLanguage, .en)
        XCTAssertEqual(manager.effectiveLanguage, .en)
        XCTAssertEqual(userDefaults.string(forKey: LanguageManager.userDefaultsKey), AppLanguage.en.rawValue)
        XCTAssertEqual(userDefaults.array(forKey: LanguageManager.appleLanguagesKey) as? [String], ["en"])
    }

    func testSetLanguageZhHansPersistsAndUpdatesEffectiveLanguage() {
        let manager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { ["en-US"] }
        )
        XCTAssertEqual(manager.effectiveLanguage, .en)

        manager.setLanguage(.zhHans)

        XCTAssertEqual(manager.selectedLanguage, .zhHans)
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)
        XCTAssertEqual(userDefaults.string(forKey: LanguageManager.userDefaultsKey), AppLanguage.zhHans.rawValue)
        XCTAssertEqual(userDefaults.array(forKey: LanguageManager.appleLanguagesKey) as? [String], ["zh-Hans", "zh-CN", "en"])
    }

    func testSetLanguageSystemRestoresEffectiveLanguageToMatchPreferred() {
        let manager = LanguageManager(
            userDefaults: userDefaults,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )

        manager.setLanguage(.en)
        XCTAssertEqual(manager.selectedLanguage, .en)
        XCTAssertEqual(manager.effectiveLanguage, .en)
        XCTAssertEqual(userDefaults.array(forKey: LanguageManager.appleLanguagesKey) as? [String], ["en"])

        manager.setLanguage(.system)
        XCTAssertEqual(manager.selectedLanguage, .system)
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)
        XCTAssertEqual(userDefaults.string(forKey: LanguageManager.userDefaultsKey), AppLanguage.system.rawValue)
        XCTAssertNil(userDefaults.persistentDomain(forName: suiteName)?[LanguageManager.appleLanguagesKey])
    }

    func testAppleLanguagesInitializationFromSavedDefaults() {
        userDefaults.set(AppLanguage.zhHans.rawValue, forKey: LanguageManager.userDefaultsKey)
        let _ = LanguageManager(userDefaults: userDefaults)
        XCTAssertEqual(userDefaults.array(forKey: LanguageManager.appleLanguagesKey) as? [String], ["zh-Hans", "zh-CN", "en"])

        userDefaults.set(AppLanguage.en.rawValue, forKey: LanguageManager.userDefaultsKey)
        let _ = LanguageManager(userDefaults: userDefaults)
        XCTAssertEqual(userDefaults.array(forKey: LanguageManager.appleLanguagesKey) as? [String], ["en"])

        userDefaults.set(AppLanguage.system.rawValue, forKey: LanguageManager.userDefaultsKey)
        let _ = LanguageManager(userDefaults: userDefaults)
        XCTAssertNil(userDefaults.persistentDomain(forName: suiteName)?[LanguageManager.appleLanguagesKey])
    }

    func testComputeEffectiveLanguageDirectly() {
        XCTAssertEqual(LanguageManager.computeEffectiveLanguage(selection: .en, preferredLanguages: ["zh-CN"]), .en)
        XCTAssertEqual(LanguageManager.computeEffectiveLanguage(selection: .zhHans, preferredLanguages: ["en-US"]), .zhHans)
        XCTAssertEqual(LanguageManager.computeEffectiveLanguage(selection: .system, preferredLanguages: ["zh-TW"]), .zhHans)
        XCTAssertEqual(LanguageManager.computeEffectiveLanguage(selection: .system, preferredLanguages: ["en-GB"]), .en)
        XCTAssertEqual(LanguageManager.computeEffectiveLanguage(selection: .system, preferredLanguages: []), .en)
    }

    func testAppLanguageProperties() {
        XCTAssertEqual(AppLanguage.system.id, "system")
        XCTAssertEqual(AppLanguage.en.id, "en")
        XCTAssertEqual(AppLanguage.zhHans.id, "zh-Hans")

        XCTAssertEqual(AppLanguage.en.displayName, "English")
        XCTAssertEqual(AppLanguage.zhHans.displayName, "简体中文")
        XCTAssertTrue([ "System", "跟随系统" ].contains(AppLanguage.system.displayName))
    }
}
