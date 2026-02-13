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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.simulatePaste()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
        let source = CGEventSource(stateID: .combinedSessionState)

        // More reliable than only setting flags on the 'v' event: press Cmd down, then V, then release.
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        cmdUp?.flags = []

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
