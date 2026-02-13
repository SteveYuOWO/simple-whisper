import SwiftUI

struct ProcessingView: View {
    @Environment(AppState.self) private var appState

    private var isEnhancing: Bool { appState.processingPhase == .enhancing }

    var body: some View {
        let lang = appState.appLanguage

        VStack(spacing: 0) {
            VStack(spacing: 14) {
                // Progress circle
                Circle()
                    .stroke(Color.bgTertiary, lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Circle()
                            .trim(from: 0, to: min(appState.transcriptionProgress, 1.0))
                            .stroke(Color.brand, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.3), value: appState.transcriptionProgress)
                    }

                Text(isEnhancing ? lang.enhancing : lang.transcribing)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.bgTertiary)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.brand)
                            .frame(width: geo.size.width * min(appState.transcriptionProgress, 1.0))
                            .animation(.linear(duration: 0.3), value: appState.transcriptionProgress)
                    }
                }
                .frame(height: 4)

                Text(isEnhancing ? lang.aiEnhancingText : lang.runningInference)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))

            Divider().overlay(Color.themeSeparator)

            HStack {
                Text("Audio: \(String(format: "%.1fs", appState.audioDuration))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text("ETA ~1s")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
    }
}
