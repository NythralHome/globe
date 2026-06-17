import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var allowsTermination = false

    static func allowTermination() {
        allowsTermination = true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppDistribution.isAppStore {
            NSApplication.shared.setActivationPolicy(.regular)
        } else {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        InstallationHealth.showTranslocationWarningIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.allowsTermination ? .terminateNow : .terminateCancel
    }
}
