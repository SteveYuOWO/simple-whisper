import Sparkle

@MainActor
final class UpdaterManager {
    private let controller: SPUStandardUpdaterController

    init() {
        // NOTE: Requires SUFeedURL in Info.plist to be set to a valid appcast URL.
        // Currently a placeholder — replace with your actual GitHub Releases appcast URL
        // and generate an EdDSA key pair using Sparkle's generate_keys tool.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
