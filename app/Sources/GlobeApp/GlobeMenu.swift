import GlobeCore
import SwiftUI

struct GlobeMenu: View {
    @ObservedObject var model: GlobeModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("Current: \(model.currentInputSourceName)")

        Divider()

        Toggle("Enable Globe", isOn: enabledBinding)

        Button("Open Settings") {
            NSApplication.shared.activate()
            openSettings()
        }

        Button("Welcome & Setup") {
            model.showOnboarding()
        }

        Button("Check Accessibility Permission") {
            model.requestAccessibilityPermission()
        }

        Button("Open Keyboard Settings") {
            model.openKeyboardSettings()
        }

        Toggle("Launch at Login", isOn: launchAtLoginBinding)

        Divider()

        Button("Quit") {
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
