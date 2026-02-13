import Foundation

enum TranscriptionState: Equatable {
    case idle
    case recording
    case processing
    case done
}

enum WhisperModel: String, CaseIterable, Identifiable {
    case tiny = "Tiny"
    case base = "Base"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var sizeDescription: String {
        switch self {
        case .tiny:   return "75 MB"
        case .base:   return "141 MB"
        case .small:  return "461 MB"
        case .medium: return "1.4 GB"
        case .large:  return "2.9 GB"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case en = "English"
    case zh = "中文"

    var id: String { rawValue }
}

enum SettingsTab: CaseIterable, Identifiable {
    case general, model, input

    var id: Self { self }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .model:   return "cpu"
        case .input:   return "mic"
        }
    }

    func title(_ lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.general, .en): return "General"
        case (.general, .zh): return "通用"
        case (.model, .en):   return "Model"
        case (.model, .zh):   return "模型"
        case (.input, .en):   return "Input"
        case (.input, .zh):   return "输入"
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case auto = "Auto-detect"
    case en = "English"
    case zh = "Chinese"
    case ja = "Japanese"
    case ko = "Korean"
    case es = "Spanish"
    case fr = "French"
    case de = "German"

    var id: String { rawValue }

    func displayName(_ appLang: AppLanguage) -> String {
        switch self {
        case .auto:
            switch appLang {
            case .en: return "Auto-detect"
            case .zh: return "自动检测"
            }
        case .en: return "English"
        case .zh: return "中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        }
    }
}
