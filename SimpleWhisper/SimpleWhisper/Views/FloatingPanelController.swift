import AppKit
import SwiftUI

final class FloatingPanelController {
    private var panel: NSPanel?
    private let appState: AppState
    // Avoid observing frame changes on the hosting view:
    // resizing the panel triggers frame changes which can cause a feedback loop
    // and make the UI feel "stuck" (looks like an invisible mask eating input).
    private var scheduledSizeUpdate: DispatchWorkItem?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Start observing transcription state, error state, and success state to auto-show/hide the panel.
    func startObservingState() {
        observeTranscriptionState()
        observeErrorState()
        observeSuccessState()
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

    private func observeSuccessState() {
        withObservationTracking {
            _ = appState.successMessage
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                self?.handleStateChange()
                self?.observeSuccessState()
            }
        }
    }

    private func handleStateChange() {
        let hasContent = appState.transcriptionState != .idle || appState.errorMessage != nil || appState.successMessage != nil
        if hasContent {
            show()
            scheduleUpdateSize()
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
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
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
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        positionAtBottomCenter(panel)
        panel.orderFrontRegardless()
        self.panel = panel
        // Coalesce size updates: SwiftUI layout may settle a tick after the panel is ordered front.
        scheduleUpdateSize()
    }

    func dismiss() {
        scheduledSizeUpdate?.cancel()
        scheduledSizeUpdate = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func scheduleUpdateSize() {
        scheduledSizeUpdate?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.updateSizeIfNeeded()
        }
        scheduledSizeUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func updateSizeIfNeeded() {
        guard let panel, let contentView = panel.contentView else { return }

        // Round up to whole pixels to avoid size "thrash" from fractional layout values.
        let fitting = contentView.fittingSize
        let newSize = NSSize(width: ceil(fitting.width), height: ceil(fitting.height))

        let current = panel.contentRect(forFrameRect: panel.frame).size
        let dw = abs(newSize.width - current.width)
        let dh = abs(newSize.height - current.height)
        guard dw > 0.5 || dh > 0.5 else { return }

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
