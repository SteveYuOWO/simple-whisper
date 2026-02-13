//
//  Created by Steve Yu on 2026/02/13.
//

import SwiftUI

@main
struct SimpleWhisperApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var appState = AppState()
    @State private var panelController: FloatingPanelController?

    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsView()
                .environment(appState)
                .onAppear {
                    if panelController == nil {
                        panelController = FloatingPanelController(appState: appState)
                    }
                }
        }
        .defaultSize(width: DS.defaultWindowSize.width, height: DS.defaultWindowSize.height)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.presented)
        .defaultPosition(.center)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disable macOS "Resume" (reopen windows from last session)
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // Clear all saved window frames
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
            where key.hasPrefix("NSWindow Frame") || key.contains("WindowFrame") {
            defaults.removeObject(forKey: key)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Delay to let SwiftUI finish its own restoration, then override
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.resetAllWindows()
        }
    }

    private func resetAllWindows() {
        for window in NSApp.windows where window.title == "Settings" {
            window.isRestorable = false
            window.setFrameAutosaveName("")

            let size = DS.defaultWindowSize
            guard let screen = window.screen ?? NSScreen.main else { continue }
            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.midY - size.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        }
    }
}
