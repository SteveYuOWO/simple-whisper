import SwiftUI

struct ProcessingView: View {
    @Environment(AppState.self) private var appState
    @State private var isSpinning = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                // Spinner
                Circle()
                    .stroke(Color.bgTertiary, lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Circle()
                            .trim(from: 0, to: 0.3)
                            .stroke(Color.brand, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(isSpinning ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
                    }
                    .onAppear { isSpinning = true }

                Text("Transcribing\u{2026}")
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
                            .animation(.linear(duration: 0.05), value: appState.transcriptionProgress)
                    }
                }
                .frame(height: 4)

                Text("Running whisper.cpp inference\u{2026}")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(EdgeInsets(top: 24, leading: 20, bottom: 16, trailing: 20))

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
