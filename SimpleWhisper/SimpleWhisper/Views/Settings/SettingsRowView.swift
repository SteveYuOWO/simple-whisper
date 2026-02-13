import SwiftUI

struct SettingsRowView: View {
    let label: String
    let value: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(height: DS.settingsRowHeight)
            .padding(.horizontal, DS.settingsHPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
