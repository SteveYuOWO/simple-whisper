import SwiftUI

struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DS.settingsCardCornerRadius))
    }
}
