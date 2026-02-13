import SwiftUI

struct SettingsHistorySection: View {
    @Environment(AppState.self) private var appState
    @State private var copiedRecordID: UUID?
    @State private var showClearConfirmation = false

    var body: some View {
        let lang = appState.appLanguage
        let history = appState.transcriptionHistory

        VStack(alignment: .leading, spacing: 12) {
            // Clear History button
            if !history.isEmpty {
                HStack {
                    Spacer()
                    if showClearConfirmation {
                        Button(lang.confirmClearHistory) {
                            appState.clearHistory()
                            showClearConfirmation = false
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)

                        Button(lang.cancel) {
                            showClearConfirmation = false
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .buttonStyle(.plain)
                    } else {
                        Button(lang.clearHistory) {
                            showClearConfirmation = true
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .buttonStyle(.plain)
                    }
                }
            }

            if history.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textTertiary)
                    Text(lang.noHistory)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(history.reversed()) { record in
                            SettingsGroupCard {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Transcription text
                                    Text(record.text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, DS.settingsHPadding)
                                        .padding(.vertical, 10)

                                    SettingsSeparator()

                                    // Metadata row
                                    HStack(spacing: 8) {
                                        Text(relativeTime(record.timestamp))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.textSecondary)

                                        Spacer()

                                        Text(metadataString(record, lang: lang))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.textTertiary)

                                        // Copy button
                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(record.text, forType: .string)
                                            copiedRecordID = record.id
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                if copiedRecordID == record.id {
                                                    copiedRecordID = nil
                                                }
                                            }
                                        } label: {
                                            Image(systemName: copiedRecordID == record.id ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 11))
                                                .foregroundStyle(copiedRecordID == record.id ? Color.success : Color.textSecondary)
                                        }
                                        .buttonStyle(.plain)

                                        // Delete button
                                        Button {
                                            appState.deleteHistoryRecord(id: record.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, DS.settingsHPadding)
                                    .frame(height: 32)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) min ago"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }

    private func metadataString(_ record: TranscriptionRecord, lang: AppLanguage) -> String {
        let duration = String(format: "%.1fs", record.audioDuration)
        let processing = String(format: "%.1fs", record.processingTime)
        return "\(duration) \u{2192} \(processing) | \(lang.wordCount(record.wordCount))"
    }
}
