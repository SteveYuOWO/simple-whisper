import Carbon
import Cocoa
import CoreGraphics

final class HotkeyManager {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    // Required modifiers
    private var requiresFn = true
    private var requiresControl = true
    private var requiresOption = false
    private var requiresCommand = false
    private var requiresShift = false

    // Required regular key (-1 = none, modifiers only)
    private var requiredKeyCode: Int64 = -1

    // "Fn" is unreliable across keyboards / macOS versions when using CGEvent flagsChanged:
    // Some setups emit a flagsChanged event for Fn but do NOT include maskSecondaryFn in event.flags.
    // Track Fn state separately with a fallback toggle based on the Function key's keycode.
    private var fnDown = false
    private var fnFlagReliable = false

    // Regular key tracking for hotkey detection
    private var isRequiredKeyHeld = false

    // Monitor mode state
    private var modifierMonitorCallback: (([String], Int64) -> Void)?
    // Accessed from event tap thread — use atomic-like volatile reads.
    // In practice, Bool assignment on Apple platforms is safe for this flag pattern.
    fileprivate var isMonitoring = false
    private var monitorCurrentKey: Int64 = -1
    private var lastMonitorModifiers: [String] = []
    private var lastMonitorKey: Int64 = -2

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHotkeyPressed = false

    // Dedicated background thread for the event tap so it is never starved
    // by heavy main-thread work (SwiftUI layout, audio I/O, Whisper inference).
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private let tapThreadReady = DispatchSemaphore(value: 0)
    private let tapThreadStopped = DispatchSemaphore(value: 0)

    // tapDisabledByTimeout can fire repeatedly while the system is under load.
    // Keep re-enabling fast, but throttle state reconciliation/logging to avoid
    // flooding queues and causing multi-second stalls.
    private var lastTapReconcileAt: CFAbsoluteTime = 0
    private var lastTapReconcileLogAt: CFAbsoluteTime = 0

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        guard eventTap == nil else { return }

        // Don't attempt event tap if accessibility is not granted — avoids system prompt
        guard Self.isAccessibilityGranted() else {
            print("[HotkeyManager] Skipping event tap: accessibility not granted.")
            return
        }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[HotkeyManager] Failed to create event tap. Accessibility permission not granted.")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source

        // Run the event tap on a dedicated background thread so macOS never
        // disables it due to the main thread being temporarily busy.
        let thread = Thread { [weak self] in
            let rl = CFRunLoopGetCurrent()!
            self?.tapRunLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            // Keep RunLoop alive even after the tap source is removed during stop().
            var ctx = CFRunLoopSourceContext()
            let dummy = CFRunLoopSourceCreate(nil, 0, &ctx)
            CFRunLoopAddSource(rl, dummy, .commonModes)
            self?.tapThreadReady.signal()
            CFRunLoopRun()
            self?.tapThreadStopped.signal()
        }
        thread.name = "com.simplewhisper.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        tapThread = thread
        tapThreadReady.wait()
        print("[HotkeyManager] Event tap started on dedicated thread.")
    }

    func stop() {
        guard let tap = eventTap else { return }
        if let rl = tapRunLoop {
            // Stop the runloop on its own thread to avoid cross-thread CFRunLoop calls.
            CFRunLoopPerformBlock(rl, CFRunLoopMode.commonModes!.rawValue) { [weak self] in
                guard let self else { return }
                CGEvent.tapEnable(tap: tap, enable: false)
                if let source = self.runLoopSource {
                    CFRunLoopRemoveSource(rl, source, .commonModes)
                }
                CFRunLoopStop(rl)
            }
            CFRunLoopWakeUp(rl)

            // Avoid waiting forever if something is wrong; best-effort stop.
            _ = tapThreadStopped.wait(timeout: .now() + .seconds(1))
        } else {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        tapThread?.cancel()
        tapThread = nil
        tapRunLoop = nil
        eventTap = nil
        runLoopSource = nil
        isHotkeyPressed = false
        isRequiredKeyHeld = false
        fnDown = false
        fnFlagReliable = false
        monitorCurrentKey = -1
        lastMonitorModifiers = []
        lastMonitorKey = -2
    }

    func startMonitor(callback: @escaping ([String], Int64) -> Void) {
        isMonitoring = true
        monitorCurrentKey = -1
        lastMonitorModifiers = []
        lastMonitorKey = -2
        modifierMonitorCallback = callback
        start()
    }

    func stopMonitor() {
        isMonitoring = false
        modifierMonitorCallback = nil
        monitorCurrentKey = -1
        lastMonitorModifiers = []
        lastMonitorKey = -2
        stop()
    }

    func updateHotkey(modifiers: [String], keyCode: Int) {
        // Hotkey config changes come from the main actor, while event processing
        // happens on the tap thread. Apply changes on the tap runloop when running
        // to avoid races in hotkey state evaluation.
        if let rl = tapRunLoop {
            CFRunLoopPerformBlock(rl, CFRunLoopMode.commonModes!.rawValue) { [weak self] in
                self?._updateHotkeyLocked(modifiers: modifiers, keyCode: keyCode)
            }
            CFRunLoopWakeUp(rl)
            return
        }
        _updateHotkeyLocked(modifiers: modifiers, keyCode: keyCode)
    }

    private func _updateHotkeyLocked(modifiers: [String], keyCode: Int) {
        var reqFn = false
        var reqControl = false
        var reqOption = false
        var reqCommand = false
        var reqShift = false

        for mod in modifiers {
            switch mod {
            case "fn": reqFn = true
            case "control": reqControl = true
            case "option": reqOption = true
            case "command": reqCommand = true
            case "shift": reqShift = true
            default: break
            }
        }

        requiresFn = reqFn
        requiresControl = reqControl
        requiresOption = reqOption
        requiresCommand = reqCommand
        requiresShift = reqShift
        requiredKeyCode = Int64(keyCode)

        // Reset latch state so changing modifiers doesn't keep recording "stuck".
        isHotkeyPressed = false
        isRequiredKeyHeld = false
        fnDown = false
        fnFlagReliable = false
    }

    // MARK: - Event Handling

    fileprivate func handleEvent(_ event: CGEvent, type: CGEventType) {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown:
            handleKeyDown(event)
        case .keyUp:
            handleKeyUp(event)
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Standard modifiers are reliable via flags.
        let controlDown = flags.contains(.maskControl)
        let optionDown = flags.contains(.maskAlternate)
        let commandDown = flags.contains(.maskCommand)
        let shiftDown = flags.contains(.maskShift)

        // Fn may be unreliable in flags. Prefer flags when it ever shows up; otherwise toggle on Fn key events.
        let fnFlag = flags.contains(.maskSecondaryFn)
        if fnFlag { fnFlagReliable = true }
        if fnFlagReliable {
            fnDown = fnFlag
        } else if keyCode == Int64(kVK_Function) {
            fnDown.toggle()
        }

        if isMonitoring {
            reportMonitorState(from: event)
            return
        }

        checkHotkeyState(
            controlDown: controlDown,
            optionDown: optionDown,
            commandDown: commandDown,
            shiftDown: shiftDown
        )
    }

    private func handleKeyDown(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if isMonitoring {
            if !isRepeat {
                monitorCurrentKey = keyCode
                reportMonitorState(from: event)
            }
            return
        }

        if !isRepeat && keyCode == requiredKeyCode {
            isRequiredKeyHeld = true
            let flags = event.flags
            checkHotkeyState(
                controlDown: flags.contains(.maskControl),
                optionDown: flags.contains(.maskAlternate),
                commandDown: flags.contains(.maskCommand),
                shiftDown: flags.contains(.maskShift)
            )
        }
    }

    private func handleKeyUp(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if isMonitoring {
            if keyCode == monitorCurrentKey {
                monitorCurrentKey = -1
            }
            reportMonitorState(from: event)
            return
        }

        if keyCode == requiredKeyCode {
            isRequiredKeyHeld = false
            let flags = event.flags
            checkHotkeyState(
                controlDown: flags.contains(.maskControl),
                optionDown: flags.contains(.maskAlternate),
                commandDown: flags.contains(.maskCommand),
                shiftDown: flags.contains(.maskShift)
            )
        }
    }

    private func reportMonitorState(from event: CGEvent) {
        let flags = event.flags
        var currentModifiers: [String] = []
        if fnDown { currentModifiers.append("fn") }
        if flags.contains(.maskControl) { currentModifiers.append("control") }
        if flags.contains(.maskAlternate) { currentModifiers.append("option") }
        if flags.contains(.maskCommand) { currentModifiers.append("command") }
        if flags.contains(.maskShift) { currentModifiers.append("shift") }

        let key = monitorCurrentKey
        if currentModifiers == lastMonitorModifiers && key == lastMonitorKey {
            return
        }
        lastMonitorModifiers = currentModifiers
        lastMonitorKey = key

        DispatchQueue.main.async { [weak self] in
            self?.modifierMonitorCallback?(currentModifiers, key)
        }
    }

    private func checkHotkeyState(
        controlDown: Bool,
        optionDown: Bool,
        commandDown: Bool,
        shiftDown: Bool
    ) {
        let modifiersMatch =
            (!requiresFn || fnDown) &&
            (!requiresControl || controlDown) &&
            (!requiresOption || optionDown) &&
            (!requiresCommand || commandDown) &&
            (!requiresShift || shiftDown)

        let keyMatch = (requiredKeyCode == -1) || isRequiredKeyHeld

        let matched = modifiersMatch && keyMatch

        // Must have at least one requirement
        let hasRequirement = requiresFn || requiresControl || requiresOption ||
            requiresCommand || requiresShift || requiredKeyCode != -1

        if matched && hasRequirement && !isHotkeyPressed {
            isHotkeyPressed = true
            print("[HotkeyManager] Hotkey DOWN detected")
            DispatchQueue.main.async { [weak self] in
                self?.onKeyDown?()
            }
        } else if !matched && isHotkeyPressed {
            isHotkeyPressed = false
            print("[HotkeyManager] Hotkey UP detected")
            DispatchQueue.main.async { [weak self] in
                self?.onKeyUp?()
            }
        }
    }

    /// Called directly on the tap thread (not main) to re-enable a timed-out tap
    /// as fast as possible. State reconciliation is performed on the tap thread,
    /// and only the user callbacks are dispatched to main.
    fileprivate func reEnableTapIfNeeded() {
        guard let tap = eventTap else { return }
        // CGEvent.tapEnable is thread-safe — call it immediately on the tap
        // thread so re-enabling is never blocked by a busy main thread.
        CGEvent.tapEnable(tap: tap, enable: true)

        // Throttle reconciliation; repeated timeout notifications can happen
        // under extreme load and would otherwise cause long stalls.
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTapReconcileAt < 0.25 {
            return
        }
        lastTapReconcileAt = now

        // Query the real keyboard state instead of blindly resetting.
        // This avoids falsely firing onKeyUp when the user is still holding
        // the hotkey (e.g. during heavy audio engine work).
        let currentFlags = CGEventSource.flagsState(.combinedSessionState)

        let fnFlag = currentFlags.contains(.maskSecondaryFn)
        if fnFlag { fnFlagReliable = true }
        if fnFlagReliable {
            fnDown = fnFlag
        }

        if requiredKeyCode >= 0 {
            isRequiredKeyHeld = CGEventSource.keyState(
                .combinedSessionState,
                key: CGKeyCode(requiredKeyCode)
            )
        }

        // Re-evaluate with actual state — fires onKeyDown/onKeyUp only
        // if the real state differs from what we previously recorded.
        checkHotkeyState(
            controlDown: currentFlags.contains(.maskControl),
            optionDown: currentFlags.contains(.maskAlternate),
            commandDown: currentFlags.contains(.maskCommand),
            shiftDown: currentFlags.contains(.maskShift)
        )

        if now - lastTapReconcileLogAt > 1.0 {
            lastTapReconcileLogAt = now
            print("[HotkeyManager] Re-enabled event tap (reconciled with live keyboard state)")
        }
    }

    // MARK: - Key Code Display Name

    static func keyCodeToDisplayName(_ keyCode: Int) -> String {
        switch keyCode {
        // Letters
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        // Numbers
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        // Function keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        // Special keys
        case kVK_Space: return "Space"
        case kVK_Return: return "\u{21A9}"       // ↩
        case kVK_Tab: return "\u{21E5}"           // ⇥
        case kVK_Delete: return "\u{232B}"        // ⌫
        case kVK_ForwardDelete: return "\u{2326}" // ⌦
        case kVK_Escape: return "\u{238B}"        // ⎋
        // Arrow keys
        case kVK_UpArrow: return "\u{2191}"       // ↑
        case kVK_DownArrow: return "\u{2193}"     // ↓
        case kVK_LeftArrow: return "\u{2190}"     // ←
        case kVK_RightArrow: return "\u{2192}"    // →
        // Navigation
        case kVK_Home: return "\u{2196}"          // ↖
        case kVK_End: return "\u{2198}"           // ↘
        case kVK_PageUp: return "\u{21DE}"        // ⇞
        case kVK_PageDown: return "\u{21DF}"      // ⇟
        // Symbols
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        // Numpad
        case kVK_ANSI_Keypad0: return "Num0"
        case kVK_ANSI_Keypad1: return "Num1"
        case kVK_ANSI_Keypad2: return "Num2"
        case kVK_ANSI_Keypad3: return "Num3"
        case kVK_ANSI_Keypad4: return "Num4"
        case kVK_ANSI_Keypad5: return "Num5"
        case kVK_ANSI_Keypad6: return "Num6"
        case kVK_ANSI_Keypad7: return "Num7"
        case kVK_ANSI_Keypad8: return "Num8"
        case kVK_ANSI_Keypad9: return "Num9"
        case kVK_ANSI_KeypadDecimal: return "Num."
        case kVK_ANSI_KeypadMultiply: return "Num*"
        case kVK_ANSI_KeypadPlus: return "Num+"
        case kVK_ANSI_KeypadMinus: return "Num-"
        case kVK_ANSI_KeypadDivide: return "Num/"
        case kVK_ANSI_KeypadEquals: return "Num="
        case kVK_ANSI_KeypadEnter: return "Num\u{21A9}"
        case kVK_ANSI_KeypadClear: return "NumClr"
        default: return "Key(\(keyCode))"
        }
    }

    deinit {
        stop()
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // Re-enable directly on the tap thread — never dispatch to main,
        // because the whole point is that main may be temporarily blocked.
        manager.reEnableTapIfNeeded()
        return Unmanaged.passUnretained(event)
    }

    // Handle on the tap thread to avoid flooding the main queue with every
    // key event. User callbacks are dispatched back to main as needed.
    manager.handleEvent(event, type: type)

    // In monitor (hotkey recording) mode, consume all key events so macOS
    // doesn't play the system alert sound for "unhandled" key presses.
    if manager.isMonitoring {
        return nil
    }

    return Unmanaged.passUnretained(event)
}
