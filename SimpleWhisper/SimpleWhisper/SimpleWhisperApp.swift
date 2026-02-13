//
//  Created by Steve Yu on 2026/02/13.
//

import SwiftUI

@main
struct SimpleWhisperApp: App {
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
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)
    }
}
