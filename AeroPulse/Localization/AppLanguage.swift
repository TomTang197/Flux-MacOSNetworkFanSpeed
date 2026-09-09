import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return LanguageManager.shared.effectiveLanguage == .zhHans ? "跟随系统" : "System"
        case .en:
            return "English"
        case .zhHans:
            return "简体中文"
        }
    }
}
