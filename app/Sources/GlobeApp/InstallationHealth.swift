import AppKit
import Foundation

enum InstallationHealth {
    static var isRunningTranslocated: Bool {
        Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    static func showTranslocationWarningIfNeeded() {
        guard isRunningTranslocated else {
            return
        }

        DispatchQueue.main.async {
            NSApplication.shared.activate()

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Move Globe to Applications"
            alert.informativeText = """
            macOS is running Globe from a temporary protected location. This can make Accessibility permission unreliable.

            Quit Globe, open the installer again, drag Globe.app to Applications, then launch it from Applications.
            """
            alert.addButton(withTitle: "Quit Globe")
            alert.addButton(withTitle: "Open Applications")
            alert.addButton(withTitle: "Continue Anyway")

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                NSApplication.shared.terminate(nil)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
            default:
                break
            }
        }
    }
}
