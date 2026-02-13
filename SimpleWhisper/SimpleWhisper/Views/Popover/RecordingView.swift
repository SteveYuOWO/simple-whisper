import SwiftUI

struct RecordingView: View {
    @Environment(AppState.self) private var appState
    @State private var animateWaveform = false

    var body: some View {
        let lang = appState.appLanguage

        VStack(spacing: 0) {
            VStack(spacing: 14) {
                // Pulsing mic circle
                Circle()
                    .fill(Color.brand)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "mic")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }

                Text(lang.listening)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                // Waveform bars
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.brand)
                            .frame(width: 4, height: barHeight(for: index))
                            .animation(
                                .easeInOut(duration: 0.4)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.05),
                                value: animateWaveform
                            )
                    }
                }
                .frame(height: 36)
                .onAppear { animateWaveform = true }
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))

            Divider().overlay(Color.themeSeparator)

            // Bottom bar
            HStack {
                Text(formatDuration(appState.recordingDuration))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.brand)
                    .monospacedDigit()
                Spacer()
                Text(lang.releaseToStop)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: [CGFloat] = [10, 22, 32, 16, 28, 12, 24, 8, 18, 26]
        let target: [CGFloat] = [24, 10, 18, 30, 14, 28, 10, 26, 12, 20]
        return animateWaveform ? target[index] : base[index]
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
