import SwiftUI

struct PopoverFooterView<RightContent: View>: View {
    let leftText: String
    @ViewBuilder let rightContent: () -> RightContent

    var body: some View {
        HStack {
            Text(leftText)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
            Spacer()
            rightContent()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
    }
}
