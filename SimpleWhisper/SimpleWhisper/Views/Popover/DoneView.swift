import SwiftUI

struct DoneView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Success checkmark
                Circle()
                    .fill(Color.success.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.success)
                    }

                Text("Typed to cursor")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                // Result text box
                Text(appState.transcribedText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))

            Divider().overlay(Color.themeSeparator)

            HStack {
                Text("\(String(format: "%.1fs", appState.audioDuration)) → \(String(format: "%.1fs", appState.processingTime))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text("\(appState.wordCount) words")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
        }
    }
}
