import SwiftUI

struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.themeSeparator)
            .frame(height: 1)
            .padding(.horizontal, DS.settingsHPadding)
    }
}
