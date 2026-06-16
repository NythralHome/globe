import GlobeCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: GlobeModel
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    tabHeader
                    selectedContent
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear {
            model.refreshSystemState()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Globe")
                        .font(.headline)
                    Text(AppVersion.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.systemImage)
                                .frame(width: 18)
                            Text(tab.title)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            permissionStatus
        }
        .padding(18)
        .frame(width: 210)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var permissionStatus: some View {
        Label(
            model.accessibilityTrusted ? "Accessibility enabled" : "Accessibility needed",
            systemImage: model.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.circle"
        )
        .font(.caption)
        .foregroundStyle(model.accessibilityTrusted ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (model.accessibilityTrusted ? Color.green : Color.orange).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private var tabHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(selectedTab.title, systemImage: selectedTab.systemImage)
                .font(.system(size: 24, weight: .semibold))
            Text(selectedTab.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .permissions:
            permissionsTab
        case .actions:
            actionsTab
        case .advanced:
            advancedTab
        case .about:
            aboutTab
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                SettingsToggleRow(title: "Enable Globe", isOn: binding(\.isEnabled))
                SettingsDivider()
                SettingsToggleRow(title: "Launch at Login", isOn: binding(\.launchAtLogin))
                SettingsDivider()
                SettingsToggleRow(title: "Show menu bar icon", isOn: binding(\.showMenuBarIcon))
                SettingsDivider()
                SettingsToggleRow(title: "Show switching HUD", isOn: binding(\.showSwitchingHUD))
            }
        }
    }

    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    Text(model.accessibilityTrusted ? "Enabled" : "Missing")
                        .fontWeight(.medium)
                        .foregroundStyle(model.accessibilityTrusted ? .green : .orange)
                }
                .font(.system(size: 15))

                SettingsDivider()

                HStack(spacing: 10) {
                    Button("Request Permission") {
                        model.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open Accessibility Settings") {
                        model.openAccessibilitySettings()
                    }
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("macOS Globe Key")
                        .font(.headline)
                    Text("Set “Press Globe key to” to “Do Nothing” so macOS does not cycle input sources before Globe can switch directly.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Open Keyboard Settings") {
                        model.openKeyboardSettings()
                    }
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Test Globe key")
                            .font(.headline)
                        Spacer()
                        Button("Reset") {
                            model.resetGlobeKeyTest()
                        }
                    }
                    Text("Press Globe/Fn. If Globe can observe the key, the status below updates immediately.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(model.lastGlobeKeyTestEvent, systemImage: "keyboard")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                SettingsPickerRow(title: "Single press") {
                    Picker("Single press", selection: sourceBinding(\.singlePress)) {
                        sourceOptions
                    }
                    .labelsHidden()
                }

                SettingsDivider()

                SettingsPickerRow(title: "Double press") {
                    Picker("Double press", selection: sourceBinding(\.doublePress)) {
                        sourceOptions
                    }
                    .labelsHidden()
                }

                SettingsDivider()

                SettingsPickerRow(title: "Triple press") {
                    Picker("Triple press", selection: sourceBinding(\.triplePress)) {
                        sourceOptions
                    }
                    .labelsHidden()
                }

                SettingsDivider()

                SettingsPickerRow(title: "Long press") {
                    Picker("Long press", selection: longPressBinding) {
                        Text("Open settings").tag(CodableGlobePressAction.openSettings)
                        Text("Show input source picker").tag(CodableGlobePressAction.showInputSourcePicker)
                        Text("Do nothing").tag(CodableGlobePressAction.none)
                    }
                    .labelsHidden()
                }
            }

            Button("Use Suggested Mapping") {
                model.applyRecommendedInputSourceMapping()
            }
        }
    }

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Multi-press timeout")
                        Spacer()
                        Text("\(model.settings.timing.multiPressTimeout, specifier: "%.2f")s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: multiPressTimeoutBinding, in: 0.20...0.60, step: 0.05)
                }

                SettingsDivider()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Long-press duration")
                        Spacer()
                        Text("\(model.settings.timing.longPressDuration, specifier: "%.2f")s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: longPressDurationBinding, in: 0.50...1.20, step: 0.05)
                }
            }

            settingsGroup {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppVersion.displayString)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 15))
            }
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "globe")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Globe")
                            .font(.title2.weight(.semibold))
                        Text("Version \(AppVersion.displayString)")
                            .foregroundStyle(.secondary)
                        Text("Open-source macOS utility under the MIT License.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Developed by Nythral")
                        .font(.headline)
                    Text("Globe is built in public for people who switch input sources many times a day. It does not record typed text.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button("Nythral Website") {
                            model.openAuthorWebsite()
                        }
                        Button("Project Website") {
                            model.openWebsite()
                        }
                        Button("Source Code") {
                            model.openRepository()
                        }
                    }
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Updates")
                        .font(.headline)
                    Text(updateDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button("Check for Updates") {
                            model.checkForUpdates()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Report a Problem") {
                            model.reportIssue()
                        }

                        Button("Export Diagnostics") {
                            model.exportDiagnostics()
                        }
                    }
                }
            }
        }
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(18)
            .frame(maxWidth: 560, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private var updateDescription: String {
        if AppDistribution.isAppStore {
            return "This build of Globe is updated by the Mac App Store. Use Check for Updates to open the App Store updates page."
        }

        return "Globe checks GitHub Releases on demand and shows what's new before you download a signed installer."
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

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case permissions
    case actions
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            "General"
        case .permissions:
            "Permissions"
        case .actions:
            "Key Actions"
        case .advanced:
            "Advanced"
        case .about:
            "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            "Core app behavior and startup options."
        case .permissions:
            "macOS access needed for direct Globe/Fn switching."
        case .actions:
            "Choose what each Globe/Fn press does."
        case .advanced:
            "Timing controls and build information."
        case .about:
            "Version, author, source, support, and updates."
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "switch.2"
        case .permissions:
            "lock.shield"
        case .actions:
            "keyboard"
        case .advanced:
            "slider.horizontal.3"
        case .about:
            "info.circle"
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
        }
        .font(.system(size: 15))
    }
}

private struct SettingsPickerRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
            Spacer()
            content
                .frame(maxWidth: 260)
        }
        .font(.system(size: 15))
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 2)
    }
}
