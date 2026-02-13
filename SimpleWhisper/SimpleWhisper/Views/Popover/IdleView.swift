import SwiftUI

struct IdleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Top content
            VStack(spacing: 16) {
                // Mic icon
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.bgSecondary)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "mic")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.textSecondary)
                    }

                Text("Simple Whisper")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                // Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.textTertiary)
                        .frame(width: 7, height: 7)
                    Text("Ready")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))

            Divider().overlay(Color.themeSeparator)

            // Hotkey hint
            HStack(spacing: 6) {
                Text(appState.hotkeyDisplay)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 4))

                Text("Hold to start recording")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, 12)

            Divider().overlay(Color.themeSeparator)

            // Footer
            PopoverFooterView(leftText: "\(appState.selectedModel.rawValue) Model") {
                HStack(spacing: 12) {
                    #if DEBUG
                    Button {
                        appState.simulateFullCycle()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Simulate full cycle")
                    #endif

                    Button {
                        NSApp.activate()
                        openWindow(id: "settings")
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
