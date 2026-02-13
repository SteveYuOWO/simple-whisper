import AppKit
import Carbon

final class TextOutputService {
    func typeText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let previousContents = pasteboard.pasteboardItems?.compactMap { item -> (String, String)? in
            guard let type = item.types.first, let data = item.string(forType: type) else { return nil }
            return (type.rawValue, data)
        }

        // Set transcribed text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Let pasteboard settle, then paste, then restore clipboard.
        // 150ms gives the pasteboard server time to propagate the change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.simulatePaste()

            // Wait long enough for the target app to read the pasteboard.
            // Some apps (Electron-based like VS Code, Slack) read asynchronously.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                pasteboard.clearContents()
                if let contents = previousContents {
                    for (typeRaw, data) in contents {
                        pasteboard.setString(data, forType: NSPasteboard.PasteboardType(typeRaw))
                    }
                }
            }
        }
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
