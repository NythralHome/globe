import GlobeCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: GlobeModel
    @State private var showsAdvancedTiming = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable Globe", isOn: binding(\.isEnabled))
                Toggle("Launch at Login", isOn: binding(\.launchAtLogin))
                Toggle("Show menu bar icon", isOn: binding(\.showMenuBarIcon))
                Toggle("Show switching HUD", isOn: binding(\.showSwitchingHUD))
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    Text(model.accessibilityTrusted ? "Enabled" : "Missing")
                        .foregroundStyle(model.accessibilityTrusted ? .green : .secondary)
                }

                Button("Request Accessibility Permission") {
                    model.requestAccessibilityPermission()
                }

                Button("Open Accessibility Settings") {
                    model.openAccessibilitySettings()
                }
            }

            Section("macOS Globe Key") {
                Text("Disable the default macOS Globe/Fn input source shortcut for predictable direct switching.")
                    .foregroundStyle(.secondary)

                Button("Open Keyboard Settings") {
                    model.openKeyboardSettings()
                }
            }

            Section("Key Actions") {
                Picker("Single press", selection: sourceBinding(\.singlePress)) {
                    sourceOptions
                }

                Picker("Double press", selection: sourceBinding(\.doublePress)) {
                    sourceOptions
                }

                Picker("Triple press", selection: sourceBinding(\.triplePress)) {
                    sourceOptions
                }

                Picker("Long press", selection: longPressBinding) {
                    Text("Open settings").tag(CodableGlobePressAction.openSettings)
                    Text("Show input source picker").tag(CodableGlobePressAction.showInputSourcePicker)
                    Text("Do nothing").tag(CodableGlobePressAction.none)
                }
            }

            Section("Timing") {
                DisclosureGroup("Advanced", isExpanded: $showsAdvancedTiming) {
                    Slider(
                        value: multiPressTimeoutBinding,
                        in: 0.20...0.60,
                        step: 0.05
                    ) {
                        Text("Multi-press timeout")
                    }
                    Text("\(model.settings.timing.multiPressTimeout, specifier: "%.2f") seconds")
                        .foregroundStyle(.secondary)

                    Slider(
                        value: longPressDurationBinding,
                        in: 0.50...1.20,
                        step: 0.05
                    ) {
                        Text("Long-press duration")
                    }
                    Text("\(model.settings.timing.longPressDuration, specifier: "%.2f") seconds")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            model.refreshSystemState()
        }
    }

    @ViewBuilder
    private var sourceOptions: some View {
        Text("Do nothing").tag(CodableGlobePressAction.none)

        ForEach(model.inputSources) { source in
            Text(source.localizedName).tag(CodableGlobePressAction.inputSource(id: source.id))
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<GlobeSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: {
                model.settings[keyPath: keyPath] = $0
                model.saveSettings()
            }
        )
    }

    private var longPressBinding: Binding<CodableGlobePressAction> {
        Binding(
            get: { model.settings.mapping.longPress },
            set: {
                model.settings.mapping.longPress = $0
                model.saveSettings()
            }
        )
    }

    private func sourceBinding(
        _ keyPath: WritableKeyPath<CodableGlobeActionMapping, CodableGlobePressAction>
    ) -> Binding<CodableGlobePressAction> {
        Binding(
            get: { model.settings.mapping[keyPath: keyPath] },
            set: {
                model.settings.mapping[keyPath: keyPath] = $0
                model.saveSettings()
            }
        )
    }

    private var multiPressTimeoutBinding: Binding<Double> {
        Binding(
            get: { model.settings.timing.multiPressTimeout },
            set: {
                model.settings.timing.multiPressTimeout = $0
                model.saveSettings()
            }
        )
    }

    private var longPressDurationBinding: Binding<Double> {
        Binding(
            get: { model.settings.timing.longPressDuration },
            set: {
                model.settings.timing.longPressDuration = $0
                model.saveSettings()
            }
        )
    }
}
