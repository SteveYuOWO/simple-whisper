import AppKit
import Carbon

final class TextOutputService {
    private struct SavedPasteboardItem {
        let representations: [(type: NSPasteboard.PasteboardType, data: Data)]
    }

    enum OutputMethod {
        /// Directly type characters at the cursor via CGEvent Unicode injection (does not touch clipboard).
        case keystrokes
        /// Write to clipboard then simulate Cmd+V (fast, but touches clipboard).
        case clipboardPaste
    }

    // Keep a sane default: avoid clipboard if possible.
    var outputMethod: OutputMethod = .keystrokes

    // Guard against overlapping work: older sessions must not interfere with newer output.
    private var session: UInt64 = 0
    private var pendingRestore: DispatchWorkItem?

    func typeText(_ text: String) {
        session &+= 1
        let currentSession = session

        pendingRestore?.cancel()

        switch outputMethod {
        case .keystrokes:
            // Type off-main; it's potentially long-running for large text.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let ok = self.simulateTyping(text, session: currentSession)
                if ok { return }
                // Fallback: some apps may ignore Unicode injection; use clipboard paste.
                DispatchQueue.main.async { [weak self] in
                    self?.pasteViaClipboard(text, session: currentSession)
                }
            }
        case .clipboardPaste:
            pasteViaClipboard(text, session: currentSession)
        }
    }

    private func pasteViaClipboard(_ text: String, session currentSession: UInt64) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard as raw data (not just string) so restoration is reliable.
        let previousItems: [SavedPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { item in
            let reps: [(NSPasteboard.PasteboardType, Data)] = item.types.compactMap { t in
                guard let d = item.data(forType: t) else { return nil }
                return (t, d)
            }
            return SavedPasteboardItem(representations: reps)
        }

        // Set transcribed text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Let pasteboard settle, then paste, then restore clipboard.
        // 150ms gives the pasteboard server time to propagate the change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.session == currentSession else { return }
            // Post events off-main; simulatePaste uses small sleeps.
            DispatchQueue.global(qos: .userInitiated).async {
                self.simulatePaste()
            }

            // Wait long enough for the target app to read the pasteboard.
            // Some apps (Electron-based like VS Code, Slack) read asynchronously.
            let restoreWork = DispatchWorkItem {
                guard self.session == currentSession else { return }
                // If we couldn't capture anything, don't clear the user's clipboard.
                guard !previousItems.isEmpty else { return }

                pasteboard.clearContents()
                let restored: [NSPasteboardItem] = previousItems.map { saved in
                    let newItem = NSPasteboardItem()
                    for rep in saved.representations {
                        newItem.setData(rep.data, forType: rep.type)
                    }
                    return newItem
                }
                _ = pasteboard.writeObjects(restored)
            }
            self.pendingRestore?.cancel()
            self.pendingRestore = restoreWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: restoreWork)
        }
    }

    private func simulateTyping(_ text: String, session currentSession: UInt64) -> Bool {
        // Type at the current cursor without touching clipboard.
        guard let source = CGEventSource(stateID: .privateState) else { return false }

        // Chunk to avoid very large single events; also gives apps time to process.
        let units = Array(text.utf16)
        let chunkSize = 64

        var i = 0
        while i < units.count {
            if session != currentSession { return true } // superseded/cancelled

            let end = min(i + chunkSize, units.count)
            let slice = units[i..<end]

            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                return false
            }

            slice.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                down.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
                up.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
            }

            down.flags = []
            up.flags = []
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            // Tiny delay helps apps that process injected events asynchronously.
            Thread.sleep(forTimeInterval: 0.001)
            i = end
        }

        return true
    }

    private func simulatePaste() {
        // Use a private event source so the synthesised key-strokes are
        // independent of the user's real keyboard state (avoids conflicts
        // when modifier keys happen to be held).
        let source = CGEventSource(stateID: .privateState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        cmdUp?.flags = []

        // Small delays between events for apps that process key events asynchronously.
        let delay: TimeInterval = 0.01
        cmdDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: delay)
        vDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: delay)
        vUp?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: delay)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
