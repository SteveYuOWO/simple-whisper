import SwiftUI

// MARK: - Hex Color Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        })
    }
}

// MARK: - Design Token Colors

extension Color {
    // Accent (constant across modes)
    static let brand = Color(hex: 0xFFCA28)
    static let brandText = Color.black

    // Backgrounds
    static let bgPrimary = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1E1E1E))
    static let bgSecondary = Color(light: Color(hex: 0xF5F5F7), dark: Color(hex: 0x2C2C2E))
    static let bgTertiary = Color(light: Color(hex: 0xE8E8ED), dark: Color(hex: 0x3A3A3C))
    static let bgGrouped = Color(light: Color(hex: 0xF2F2F7), dark: Color(hex: 0x2C2C2E))

    // Text
    static let textPrimary = Color(light: Color(hex: 0x1D1D1F), dark: Color(hex: 0xF5F5F7))
    static let textSecondary = Color(light: Color(hex: 0x86868B), dark: Color(hex: 0xA1A1A6))
    static let textTertiary = Color(light: Color(hex: 0xAEAEB2), dark: Color(hex: 0x6E6E73))

    // UI Elements
    static let themeSeparator = Color(light: Color(hex: 0xD1D1D6), dark: Color(hex: 0x38383A))
    static let fillControl = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x636366))
    static let fillToggleOff = Color(light: Color(hex: 0xE5E5EA), dark: Color(hex: 0x4A4A4C))

    // Success
    static let success = Color(hex: 0x34C759)
}

// MARK: - Design Constants

enum DS {
    // Popover
    static let popoverWidth: CGFloat = 280
    static let popoverCornerRadius: CGFloat = 12

    // Settings
    static let settingsSidebarWidth: CGFloat = 200
    static let settingsMinWidth: CGFloat = 600
    static let settingsMinHeight: CGFloat = 400

    static var defaultWindowSize: CGSize {
        guard let screen = NSScreen.main else { return CGSize(width: 900, height: 560) }
        let frame = screen.visibleFrame
        let w = round(frame.width * 0.6)
        let h = round(frame.height * 0.6)
        return CGSize(width: max(w, settingsMinWidth), height: max(h, settingsMinHeight))
    }
    static let settingsRowHeight: CGFloat = 44
    static let settingsSectionGap: CGFloat = 20
    static let settingsCardCornerRadius: CGFloat = 10
    static let settingsHPadding: CGFloat = 16

    // Shadow
    static let shadowColor = Color.black.opacity(0.094)
    static let shadowRadius: CGFloat = 20
    static let shadowY: CGFloat = 4
}
