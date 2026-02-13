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

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case model = "Model"
    case input = "Input"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .model:   return "cpu"
        case .input:   return "mic"
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
}
