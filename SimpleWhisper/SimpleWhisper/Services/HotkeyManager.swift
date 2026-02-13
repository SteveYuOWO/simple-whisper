import Carbon
import Cocoa
import CoreGraphics

final class HotkeyManager {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    // "Fn" is unreliable across keyboards / macOS versions when using CGEvent flagsChanged:
    // Some setups emit a flagsChanged event for Fn but do NOT include maskSecondaryFn in event.flags.
    // Track Fn state separately with a fallback toggle based on the Function key's keycode.
    private(set) var requiredModifiers: CGEventFlags = [.maskSecondaryFn, .maskControl]
    private var requiresFn = true
    private var requiresControl = true
    private var requiresOption = false
    private var requiresCommand = false
    private var requiresShift = false

    private var fnDown = false
    private var fnFlagReliable = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHotkeyPressed = false

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

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let observer = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: observer
        ) else {
            Unmanaged<HotkeyManager>.fromOpaque(observer).release()
            print("[HotkeyManager] Failed to create event tap. Accessibility permission not granted.")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyManager] Event tap started successfully.")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isHotkeyPressed = false
        fnDown = false
        fnFlagReliable = false
    }

    func updateModifiers(from modifierStrings: [String]) {
        var flags: CGEventFlags = []
        var reqFn = false
        var reqControl = false
        var reqOption = false
        var reqCommand = false
        var reqShift = false

        for mod in modifierStrings {
            switch mod {
            case "fn":
                flags.insert(.maskSecondaryFn)
                reqFn = true
            case "control":
                flags.insert(.maskControl)
                reqControl = true
            case "option":
                flags.insert(.maskAlternate)
                reqOption = true
            case "command":
                flags.insert(.maskCommand)
                reqCommand = true
            case "shift":
                flags.insert(.maskShift)
                reqShift = true
            default: break
            }
        }

        requiredModifiers = flags
        requiresFn = reqFn
        requiresControl = reqControl
        requiresOption = reqOption
        requiresCommand = reqCommand
        requiresShift = reqShift

        // Reset latch state so changing modifiers doesn't keep recording "stuck".
        isHotkeyPressed = false
        fnDown = false
        fnFlagReliable = false
    }

    fileprivate func handleFlagsChanged(_ event: CGEvent) {
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
            // Fallback: if Fn generates flagsChanged events but doesn't update flags, toggling keeps state correct.
            fnDown.toggle()
        }

        let matched =
            (!requiresFn || fnDown) &&
            (!requiresControl || controlDown) &&
            (!requiresOption || optionDown) &&
            (!requiresCommand || commandDown) &&
            (!requiresShift || shiftDown)

        if matched && !isHotkeyPressed {
            isHotkeyPressed = true
            print("[HotkeyManager] Hotkey DOWN detected")
            onKeyDown?()
        } else if !matched && isHotkeyPressed {
            isHotkeyPressed = false
            print("[HotkeyManager] Hotkey UP detected")
            onKeyUp?()
        }
    }

    fileprivate func reEnableTapIfNeeded() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[HotkeyManager] Re-enabled event tap after timeout")
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
        DispatchQueue.main.async {
            manager.reEnableTapIfNeeded()
        }
        return Unmanaged.passUnretained(event)
    }

    let flags = event.flags

    DispatchQueue.main.async {
        manager.handleFlagsChanged(event)
    }

    return Unmanaged.passUnretained(event)
}
