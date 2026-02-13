import Foundation

enum TranscriptionState: Equatable {
    case idle
    case recording
    case processing
    case done
}

enum WhisperModel: String, CaseIterable, Identifiable, Codable {
    case tiny = "Tiny"
    case base = "Base"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var modelName: String {
        switch self {
        case .tiny:   return "openai_whisper-tiny"
        case .base:   return "openai_whisper-base"
        case .small:  return "openai_whisper-small"
        case .medium: return "openai_whisper-medium"
        case .large:  return "openai_whisper-large-v3"
        }
    }

    static let modelRepo = "argmaxinc/whisperkit-coreml"

    var sizeDescription: String {
        switch self {
        case .tiny:   return "~40 MB"
        case .base:   return "~80 MB"
        case .small:  return "~250 MB"
        case .medium: return "~750 MB"
        case .large:  return "~1.5 GB"
        }
    }

    func pickerLabel(_ lang: AppLanguage) -> String {
        let base = "\(rawValue) (\(sizeDescription))"
        switch (self, lang) {
        case (.base, .en):  return base + " (Recommended)"
        case (.base, .zh):  return base + "（推荐）"
        case (.large, .en): return base + " (Most Accurate)"
        case (.large, .zh): return base + "（最精准）"
        default:            return base
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case en = "English"
    case zh = "中文"

    var id: String { rawValue }
}

enum SettingsTab: CaseIterable, Identifiable {
    case input, general, model

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

enum Language: String, CaseIterable, Identifiable, Codable {
    case auto = "Auto-detect"
    case en = "English"
    case zh = "Chinese"
    case ja = "Japanese"
    case ko = "Korean"
    case es = "Spanish"
    case fr = "French"
    case de = "German"

    var id: String { rawValue }

    var whisperCode: String? {
        switch self {
        case .auto: return nil
        case .en: return "en"
        case .zh: return "zh"
        case .ja: return "ja"
        case .ko: return "ko"
        case .es: return "es"
        case .fr: return "fr"
        case .de: return "de"
        }
    }

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
