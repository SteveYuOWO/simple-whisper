import AppKit
import SwiftUI

final class FloatingPanelController {
    private var panel: NSPanel?
    private let appState: AppState
    private var sizeObserver: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Start observing transcription state and error state to auto-show/hide the panel.
    func startObservingState() {
        observeTranscriptionState()
        observeErrorState()
    }

    private func observeTranscriptionState() {
        withObservationTracking {
            _ = appState.transcriptionState
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                self?.handleStateChange()
                self?.observeTranscriptionState()
            }
        }
    }

    private func observeErrorState() {
        withObservationTracking {
            _ = appState.errorMessage
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                self?.handleStateChange()
                self?.observeErrorState()
            }
        }
    }

    private func handleStateChange() {
        let hasContent = appState.transcriptionState != .idle || appState.errorMessage != nil
        if hasContent {
            show()
        } else {
            dismiss()
        }
    }

    func show() {
        if panel != nil { return }

        let hostingView = NSHostingView(
            rootView: FloatingPillView()
                .environment(appState)
        )
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        positionAtBottomCenter(panel)
        panel.orderFrontRegardless()
        self.panel = panel

        // Observe content size changes to auto-resize the panel
        sizeObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: hostingView,
            queue: .main
        ) { [weak self] _ in
            self?.updateSize()
        }
        hostingView.postsFrameChangedNotifications = true
    }

    func dismiss() {
        if let sizeObserver {
            NotificationCenter.default.removeObserver(sizeObserver)
        }
        sizeObserver = nil
        panel?.orderOut(nil)
        panel = nil
    }

    func updateSize() {
        guard let panel, let contentView = panel.contentView else { return }
        let newSize = contentView.fittingSize
        panel.setContentSize(newSize)
        positionAtBottomCenter(panel)
    }

    private func positionAtBottomCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
