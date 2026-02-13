import SwiftUI

struct PopoverView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.transcriptionState {
            case .idle:
                IdleView()
            case .recording:
                RecordingView()
            case .processing:
                ProcessingView()
            case .done:
                DoneView()
            }
        }
        .frame(width: DS.popoverWidth)
        .background(Color.bgPrimary)
    }
}
