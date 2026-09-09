import Foundation
import Combine

public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()
    
    public static let userDefaultsKey = "AppLanguagePreference"
    
    private let userDefaults: UserDefaults
    private let preferredLanguagesProvider: () -> [String]
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var selectedLanguage: AppLanguage
    @Published public private(set) var effectiveLanguage: AppLanguage

    public init(
        userDefaults: UserDefaults = .standard,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.userDefaults = userDefaults
        self.preferredLanguagesProvider = preferredLanguagesProvider
        
        let savedRaw = userDefaults.string(forKey: Self.userDefaultsKey) ?? AppLanguage.system.rawValue
        let initialSelection = AppLanguage(rawValue: savedRaw) ?? .system
        self.selectedLanguage = initialSelection
        self.effectiveLanguage = Self.computeEffectiveLanguage(
            selection: initialSelection,
            preferredLanguages: preferredLanguagesProvider()
        )

        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshEffectiveLanguage()
            }
            .store(in: &cancellables)
    }

    public func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        userDefaults.set(language.rawValue, forKey: Self.userDefaultsKey)
        refreshEffectiveLanguage()
    }

    public func refreshEffectiveLanguage() {
        let newEffective = Self.computeEffectiveLanguage(
            selection: selectedLanguage,
            preferredLanguages: preferredLanguagesProvider()
        )
        if effectiveLanguage != newEffective {
            effectiveLanguage = newEffective
        }
        objectWillChange.send()
    }

    public static func computeEffectiveLanguage(
        selection: AppLanguage,
        preferredLanguages: [String]
    ) -> AppLanguage {
        switch selection {
        case .en:
            return .en
        case .zhHans:
            return .zhHans
        case .system:
            let primary = preferredLanguages.first ?? "en"
            if primary.hasPrefix("zh") {
                return .zhHans
            }
            return .en
        }
    }
}
