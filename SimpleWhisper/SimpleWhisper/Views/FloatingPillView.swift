import SwiftUI

struct FloatingPillView: View {
    @Environment(AppState.self) private var appState

    private var lang: AppLanguage { appState.appLanguage }
    private let maxMessageTextWidth: CGFloat = 360

    var body: some View {
        VStack(spacing: 8) {
            if let successMessage = appState.successMessage {
                successPill(message: successMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let errorMessage = appState.errorMessage {
                errorPill(message: errorMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if appState.transcriptionState != .idle {
                Group {
                    switch appState.transcriptionState {
                    case .idle:
                        EmptyView()
                    case .recording:
                        recordingPill
                    case .processing:
                        processingPill
                    case .enhancing:
                        enhancingPill
                    case .done:
                        donePill
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fixedSize()
        .animation(.spring(duration: 0.3), value: appState.transcriptionState)
        .animation(.spring(duration: 0.3), value: appState.errorMessage)
        .animation(.spring(duration: 0.3), value: appState.successMessage)
    }

    // MARK: - Success

    private func successPill(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.success)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxMessageTextWidth, alignment: .leading)
        }
        .pillStyle()
    }

    // MARK: - Error

    private func errorPill(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: 0xFF6B6B))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxMessageTextWidth, alignment: .leading)
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
        }
        .pillStyle()
    }

    // MARK: - Processing

    private var processingPill: some View {
        HStack(spacing: 10) {
            SpinnerRing()
            Text(lang.processing)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .pillStyle()
    }

    // MARK: - Enhancing

    private var enhancingPill: some View {
        HStack(spacing: 10) {
            SpinnerRing()
            Text(lang.processing)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .pillStyle()
    }

    // MARK: - Done

    private var donePill: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.success)
            Text(lang.done)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Color(hex: 0x48484A)
                .frame(width: 1, height: 14)
            Text(lang.wordCount(appState.wordCount))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.38))
        }
        .pillStyle()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        // Keep a stable width so the floating panel doesn't resize every minute boundary.
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Pill Style Modifier

private struct PillStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: 20)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(hex: 0x1C1C1E), in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
    }
}

extension View {
    fileprivate func pillStyle() -> some View {
        modifier(PillStyleModifier())
    }
}

// MARK: - Spinner Ring

private struct SpinnerRing: View {
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .stroke(Color(hex: 0x48484A), lineWidth: 2)
            .frame(width: 16, height: 16)
            .overlay {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isSpinning)
            }
            .onAppear { isSpinning = true }
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
