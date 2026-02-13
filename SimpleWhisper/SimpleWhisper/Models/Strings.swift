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
    var downloadModel: String {
        switch self {
        case .en: "Download"
        case .zh: "下载"
        }
    }
    var downloading: String {
        switch self {
        case .en: "Downloading\u{2026}"
        case .zh: "下载中\u{2026}"
        }
    }
    var downloaded: String {
        switch self {
        case .en: "Downloaded"
        case .zh: "已下载"
        }
    }
    var deleteModel: String {
        switch self {
        case .en: "Delete Model"
        case .zh: "删除模型"
        }
    }
    var downloadFailed: String {
        switch self {
        case .en: "Download Failed"
        case .zh: "下载失败"
        }
    }
    var retry: String {
        switch self {
        case .en: "Retry"
        case .zh: "重试"
        }
    }
    var cancel: String {
        switch self {
        case .en: "Cancel"
        case .zh: "取消"
        }
    }
    var loadingModel: String {
        switch self {
        case .en: "Loading model\u{2026}"
        case .zh: "加载模型中\u{2026}"
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
    var permissionRequired: String {
        switch self {
        case .en: "Accessibility Permission Required"
        case .zh: "需要辅助功能权限"
        }
    }
    var openSystemSettings: String {
        switch self {
        case .en: "Open System Settings"
        case .zh: "打开系统设置"
        }
    }
    var permissionGranted: String {
        switch self {
        case .en: "Permission Granted"
        case .zh: "已授权"
        }
    }
    var permissionNotGranted: String {
        switch self {
        case .en: "Not Granted"
        case .zh: "未授权"
        }
    }
    var microphonePermission: String {
        switch self {
        case .en: "Microphone Permission"
        case .zh: "麦克风权限"
        }
    }
    var requestPermission: String {
        switch self {
        case .en: "Request"
        case .zh: "申请权限"
        }
    }
    var accessibilityPermission: String {
        switch self {
        case .en: "Accessibility"
        case .zh: "辅助功能"
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
    var processing: String {
        switch self {
        case .en: "Processing\u{2026}"
        case .zh: "处理中\u{2026}"
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
        case .en: "Running WhisperKit inference\u{2026}"
        case .zh: "正在运行 WhisperKit 推理\u{2026}"
        }
    }
    var done: String {
        switch self {
        case .en: "Done"
        case .zh: "完成"
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
}
