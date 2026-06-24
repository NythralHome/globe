import GlobeCore
import SwiftUI

struct GlobeMenu: View {
    @ObservedObject var model: GlobeModel

    var body: some View {
        Text("Current: \(model.currentInputSourceName)")

        Divider()

        Toggle("Enable Globe", isOn: enabledBinding)

        Button("Open Settings") {
            model.showSettingsWindow()
        }

        Button("Welcome & Setup") {
            model.showOnboarding()
        }

        Button(AppDistribution.usesInAppUpdates ? "Check for Updates" : "Open App Store Updates") {
            model.checkForUpdates()
        }

        #if !GLOBE_APP_STORE
        Button("Request Input Monitoring") {
            model.beginInputMonitoringSetup()
        }
        #endif

        Button("Open Keyboard Settings") {
            model.openKeyboardSettings()
        }

        Toggle("Launch at Login", isOn: launchAtLoginBinding)

        Divider()

        Button("Report a Problem") {
            model.reportIssue()
        }

        Button("Export Diagnostics") {
            model.exportDiagnostics()
        }

        Button("Open Project Website") {
            model.openWebsite()
        }

        Text("Globe \(AppVersion.displayString)")
            .foregroundStyle(.secondary)

        Button("Quit") {
            AppDelegate.allowTermination()
            NSApplication.shared.terminate(nil)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { model.settings.isEnabled },
            set: {
                model.settings.isEnabled = $0
                model.saveSettings()
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLogin },
            set: {
                model.settings.launchAtLogin = $0
                model.saveSettings()
            }
        )
    }
}
