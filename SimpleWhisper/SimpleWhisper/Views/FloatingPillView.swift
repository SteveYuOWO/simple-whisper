import SwiftUI

struct FloatingPillView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.transcriptionState {
            case .idle:
                idlePill
            case .recording:
                recordingPill
            case .processing:
                processingPill
            case .done:
                donePill
            }
        }
        .animation(.spring(duration: 0.3), value: appState.transcriptionState)
    }

    // MARK: - Idle

    private var idlePill: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            Circle()
                .fill(Color(white: 0.28))
                .frame(width: 6, height: 6)
            Text("Ready")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .pillStyle()
    }

    // MARK: - Recording

    private var recordingPill: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            Text(formatDuration(appState.recordingDuration))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.93))
                .monospacedDigit()
            WaveformBars()
            Text("Release to stop")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.38))
        }
        .pillStyle()
    }

    // MARK: - Processing

    private var processingPill: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(.white.opacity(0.6))
            Text("Transcribing\u{2026}")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            ProgressView(value: appState.transcriptionProgress)
                .frame(width: 80)
                .tint(Color.brand)
        }
        .pillStyle()
    }

    // MARK: - Done

    private var donePill: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.success)
            Text("Typed to cursor")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Rectangle()
                .fill(Color(white: 0.28))
                .frame(width: 1, height: 14)
            Text("\(appState.wordCount) words")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.38))
        }
        .pillStyle()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Pill Style Modifier

private struct PillStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(.black.opacity(0.88), in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 30, y: 8)
    }
}

extension View {
    fileprivate func pillStyle() -> some View {
        modifier(PillStyleModifier())
    }
}

// MARK: - Waveform Bars

private struct WaveformBars: View {
    @State private var animate = false

    private let barHeights: [CGFloat] = [8, 16, 20, 12, 18, 10, 14]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brand)
                    .frame(width: 3, height: animate ? barHeights[i] : barHeights[(i + 3) % 7])
            }
        }
        .frame(height: 20)
        .animation(
            .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
            value: animate
        )
        .onAppear { animate = true }
    }
}
