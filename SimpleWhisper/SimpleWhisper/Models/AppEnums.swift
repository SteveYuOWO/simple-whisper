import Foundation

enum TranscriptionState: Equatable {
    case idle
    case recording
    case processing
    case done
}

enum ProcessingPhase: Equatable {
    case transcribing
    case enhancing
}

struct LLMModelOption: Identifiable, Hashable {
    let id: String          // API model ID
    let displayName: String
    let costEstimate: String // monthly cost at 1h/day
    let isRecommended: Bool
    let isMostAccurate: Bool

    func label(_ lang: AppLanguage) -> String {
        if isRecommended {
            return "\(displayName)" + (lang == .en ? " (Recommended)" : "（推荐）")
        } else if isMostAccurate {
            return "\(displayName)" + (lang == .en ? " (Most Accurate)" : "（最精准）")
        }
        return displayName
    }
}

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case openai = "openai"
    case claude = "claude"

    var id: String { rawValue }

    func displayName(_ lang: AppLanguage) -> String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Claude"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .claude: return "claude-haiku-4-5-20251001"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .claude: return "https://api.anthropic.com/v1/messages"
        }
    }

    var models: [LLMModelOption] {
        switch self {
        case .openai: return [
            LLMModelOption(id: "gpt-4o-mini", displayName: "GPT-4o-mini", costEstimate: "~$0.45", isRecommended: true, isMostAccurate: false),
            LLMModelOption(id: "gpt-4o", displayName: "GPT-4o", costEstimate: "~$12", isRecommended: false, isMostAccurate: true),
        ]
        case .claude: return [
            LLMModelOption(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku", costEstimate: "~$0.9", isRecommended: true, isMostAccurate: false),
            LLMModelOption(id: "claude-sonnet-4-5-20250929", displayName: "Claude Sonnet", costEstimate: "~$10–12", isRecommended: false, isMostAccurate: true),
        ]
        }
    }
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
    case input, general, model, ai, history

    var id: Self { self }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .model:   return "cpu"
        case .input:   return "mic"
        case .ai:      return "sparkles"
        case .history: return "clock.arrow.circlepath"
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
        case (.ai, .en):      return "AI Enhance"
        case (.ai, .zh):      return "AI 优化"
        case (.history, .en): return "History"
        case (.history, .zh): return "历史记录"
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
    case ru = "Russian"
    case pt = "Portuguese"
    case it = "Italian"
    case nl = "Dutch"
    case ar = "Arabic"
    case hi = "Hindi"
    case tr = "Turkish"
    case pl = "Polish"
    case sv = "Swedish"
    case vi = "Vietnamese"
    case th = "Thai"
    case ind = "Indonesian"
    case uk = "Ukrainian"
    case cs = "Czech"
    case ro = "Romanian"
    case da = "Danish"
    case fi = "Finnish"
    case el = "Greek"
    case hu = "Hungarian"
    case no = "Norwegian"
    case he = "Hebrew"
    case ms = "Malay"
    case bg = "Bulgarian"
    case hr = "Croatian"
    case sk = "Slovak"
    case sl = "Slovenian"
    case sr = "Serbian"
    case ca = "Catalan"
    case fa = "Persian"
    case ta = "Tamil"
    case bn = "Bengali"
    case ur = "Urdu"
    case af = "Afrikaans"
    case sw = "Swahili"
    case tl = "Tagalog"
    case lt = "Lithuanian"
    case lv = "Latvian"
    case et = "Estonian"

    var id: String { rawValue }

    var whisperCode: String? {
        switch self {
        case .auto: return nil
        case .en:  return "en"
        case .zh:  return "zh"
        case .ja:  return "ja"
        case .ko:  return "ko"
        case .es:  return "es"
        case .fr:  return "fr"
        case .de:  return "de"
        case .ru:  return "ru"
        case .pt:  return "pt"
        case .it:  return "it"
        case .nl:  return "nl"
        case .ar:  return "ar"
        case .hi:  return "hi"
        case .tr:  return "tr"
        case .pl:  return "pl"
        case .sv:  return "sv"
        case .vi:  return "vi"
        case .th:  return "th"
        case .ind: return "id"
        case .uk:  return "uk"
        case .cs:  return "cs"
        case .ro:  return "ro"
        case .da:  return "da"
        case .fi:  return "fi"
        case .el:  return "el"
        case .hu:  return "hu"
        case .no:  return "no"
        case .he:  return "he"
        case .ms:  return "ms"
        case .bg:  return "bg"
        case .hr:  return "hr"
        case .sk:  return "sk"
        case .sl:  return "sl"
        case .sr:  return "sr"
        case .ca:  return "ca"
        case .fa:  return "fa"
        case .ta:  return "ta"
        case .bn:  return "bn"
        case .ur:  return "ur"
        case .af:  return "af"
        case .sw:  return "sw"
        case .tl:  return "tl"
        case .lt:  return "lt"
        case .lv:  return "lv"
        case .et:  return "et"
        }
    }

    func displayName(_ appLang: AppLanguage) -> String {
        switch self {
        case .auto:
            switch appLang {
            case .en: return "Auto-detect"
            case .zh: return "自动检测"
            }
        case .en:  return "English"
        case .zh:  return "中文"
        case .ja:  return "日本語"
        case .ko:  return "한국어"
        case .es:  return "Español"
        case .fr:  return "Français"
        case .de:  return "Deutsch"
        case .ru:  return "Русский"
        case .pt:  return "Português"
        case .it:  return "Italiano"
        case .nl:  return "Nederlands"
        case .ar:  return "العربية"
        case .hi:  return "हिन्दी"
        case .tr:  return "Türkçe"
        case .pl:  return "Polski"
        case .sv:  return "Svenska"
        case .vi:  return "Tiếng Việt"
        case .th:  return "ไทย"
        case .ind: return "Bahasa Indonesia"
        case .uk:  return "Українська"
        case .cs:  return "Čeština"
        case .ro:  return "Română"
        case .da:  return "Dansk"
        case .fi:  return "Suomi"
        case .el:  return "Ελληνικά"
        case .hu:  return "Magyar"
        case .no:  return "Norsk"
        case .he:  return "עברית"
        case .ms:  return "Bahasa Melayu"
        case .bg:  return "Български"
        case .hr:  return "Hrvatski"
        case .sk:  return "Slovenčina"
        case .sl:  return "Slovenščina"
        case .sr:  return "Српски"
        case .ca:  return "Català"
        case .fa:  return "فارسی"
        case .ta:  return "தமிழ்"
        case .bn:  return "বাংলা"
        case .ur:  return "اردو"
        case .af:  return "Afrikaans"
        case .sw:  return "Kiswahili"
        case .tl:  return "Filipino"
        case .lt:  return "Lietuvių"
        case .lv:  return "Latviešu"
        case .et:  return "Eesti"
        }
    }
}
