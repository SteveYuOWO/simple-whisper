import Foundation

// MARK: - Localized Strings

extension AppLanguage {
    // MARK: Settings - General

    var launchAtLogin: String {
        switch self {
        case .en: "Launch at Login"
        case .zh: "登录时启动"
        }
    }
    var soundFeedback: String {
        switch self {
        case .en: "Sound Feedback"
        case .zh: "声音反馈"
        }
    }
    var autoPunctuation: String {
        switch self {
        case .en: "Auto Punctuation"
        case .zh: "自动标点"
        }
    }
    var showInDock: String {
        switch self {
        case .en: "Show in Dock"
        case .zh: "在 Dock 中显示"
        }
    }
    var language: String {
        switch self {
        case .en: "Language"
        case .zh: "语言"
        }
    }

    // MARK: Settings - Model

    var whisperModel: String {
        switch self {
        case .en: "Whisper Model"
        case .zh: "Whisper 模型"
        }
    }
    var modelHint: String {
        switch self {
        case .en: "Smaller models are faster but less accurate. Larger models require more memory."
        case .zh: "较小的模型速度更快但准确度较低，较大的模型需要更多内存。"
        }
    }

    // MARK: Settings - Input

    var microphone: String {
        switch self {
        case .en: "Microphone"
        case .zh: "麦克风"
        }
    }
    var hotkey: String {
        switch self {
        case .en: "Hotkey"
        case .zh: "快捷键"
        }
    }
    var holdToRecord: String {
        switch self {
        case .en: "Hold to record"
        case .zh: "按住录音"
        }
    }

    // MARK: Popover

    var ready: String {
        switch self {
        case .en: "Ready"
        case .zh: "就绪"
        }
    }
    var holdToStartRecording: String {
        switch self {
        case .en: "Hold to start recording"
        case .zh: "按住开始录音"
        }
    }
    var listening: String {
        switch self {
        case .en: "Listening\u{2026}"
        case .zh: "聆听中\u{2026}"
        }
    }
    var releaseToStop: String {
        switch self {
        case .en: "Release to stop"
        case .zh: "松开停止"
        }
    }
    var transcribing: String {
        switch self {
        case .en: "Transcribing\u{2026}"
        case .zh: "转录中\u{2026}"
        }
    }
    var runningInference: String {
        switch self {
        case .en: "Running whisper.cpp inference\u{2026}"
        case .zh: "正在运行 whisper.cpp 推理\u{2026}"
        }
    }
    var typedToCursor: String {
        switch self {
        case .en: "Typed to cursor"
        case .zh: "已输入到光标"
        }
    }
    func wordCount(_ count: Int) -> String {
        switch self {
        case .en: "\(count) words"
        case .zh: "\(count) 个词"
        }
    }
    var testFloatingPanel: String {
        switch self {
        case .en: "Test Floating Panel"
        case .zh: "测试悬浮面板"
        }
    }
}
