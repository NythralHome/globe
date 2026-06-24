import AppKit
import GlobeCore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: GlobeModel
    @State private var step = 0

    private var steps: [OnboardingStep] {
        #if GLOBE_APP_STORE
        [
            OnboardingStep(
                kind: .intro,
                icon: "globe",
                title: "Globe",
                subtitle: "Direct language switching for macOS.",
                body: "Press Control-Option-Z anywhere to switch directly to the input source you choose. Globe Pro adds direct Globe/Fn switching outside the Mac App Store."
            ),
            OnboardingStep(
                kind: .privacy,
                icon: "lock.shield",
                title: "Private by Design",
                subtitle: "Globe does not read typed text.",
                body: "The Mac App Store build uses a registered system hotkey. It does not request Accessibility access and does not monitor typed text."
            ),
            OnboardingStep(
                kind: .keyboardSetup,
                icon: "switch.2",
                title: "Global Shortcut",
                subtitle: "Start with Control-Option-Z, then customize.",
                body: "The App Store edition uses standard global shortcuts so it can work without Accessibility permissions. You can change the main shortcut and add direct shortcuts for individual languages."
            ),
            OnboardingStep(
                kind: .actions,
                icon: "keyboard",
                title: "Key Actions",
                subtitle: "Choose your direct switches.",
                body: "Assign installed input sources to single, double, and triple presses of your main shortcut, or give each language its own direct shortcut."
            ),
            OnboardingStep(
                kind: .ready,
                icon: "power",
                title: "Ready",
                subtitle: "Globe is ready.",
                body: "Globe runs quietly in the menu bar. You can choose whether it should launch at login."
            )
        ]
        #else
        var items = [
            OnboardingStep(
                kind: .intro,
                icon: "globe",
                title: "Globe",
                subtitle: "Direct language switching for macOS.",
                body: "Press Globe/Fn once, twice, or three times to jump straight to the input source you choose. Hold Globe/Fn to open settings."
            ),
            OnboardingStep(
                kind: .privacy,
                icon: "lock.shield",
                title: "Private by Design",
                subtitle: "Globe does not read typed text.",
                body: "Globe does not record, store, or transmit typed text. It listens for Globe/Fn key state changes so it can switch input sources."
            ),
            OnboardingStep(
                kind: .keyboardSetup,
                icon: "switch.2",
                title: "macOS Setup",
                subtitle: "Turn off the default Globe key action.",
                body: "Set “Press Globe key to” to “Do Nothing” in Keyboard settings. This prevents macOS from cycling languages before Globe can switch directly."
            )
        ]

        items.append(
            OnboardingStep(
                kind: .permissions,
                icon: "checkmark.seal",
                title: "Permissions",
                subtitle: "Allow Input Monitoring.",
                body: "macOS requires Input Monitoring permission for apps that listen for global keyboard control events. Globe uses it only to detect Globe/Fn."
            )
        )

        items.append(
            contentsOf: [
                OnboardingStep(
                    kind: .actions,
                    icon: "keyboard",
                    title: "Key Actions",
                    subtitle: "Choose your direct switches.",
                    body: "Assign installed input sources to single, double, and triple Globe/Fn presses."
                ),
                OnboardingStep(
                    kind: .ready,
                    icon: "power",
                    title: "Ready",
                    subtitle: "Globe is ready.",
                    body: "Globe runs quietly in the menu bar. You can choose whether it should launch at login."
                )
            ]
        )

        return items
        #endif
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            VStack(spacing: 0) {
                content

                Divider()

                footer
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.refreshSystemState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshSystemState()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Globe")
                        .font(.headline)
                    Text("Beta setup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Button {
                        step = index
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: steps[index].icon)
                                .frame(width: 18)
                            Text(steps[index].title)
                                .lineLimit(1)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: step == index ? .semibold : .regular))
                        .foregroundStyle(step == index ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(step == index ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            #if GLOBE_APP_STORE
            statusPill(
                title: "Mac App Store ready",
                systemImage: "checkmark.circle.fill",
                color: .green
            )
            #else
            statusPill(
                title: model.inputMonitoringTrusted ? "Input Monitoring enabled" : "Input Monitoring needed",
                systemImage: model.inputMonitoringTrusted ? "checkmark.circle.fill" : "exclamationmark.circle",
                color: model.inputMonitoringTrusted ? .green : .orange
            )
            #endif
        }
        .padding(22)
        .frame(width: 250)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 10)

            Image(systemName: steps[step].icon)
                .font(.system(size: 48, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                Text(steps[step].title)
                    .font(.system(size: 34, weight: .semibold))
                Text(steps[step].subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(steps[step].body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            stepControls

            Spacer()
        }
        .padding(.horizontal, 44)
        .padding(.top, 42)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var stepControls: some View {
        switch steps[step].kind {
        case .keyboardSetup:
            VStack(alignment: .leading, spacing: 10) {
                Button("Open Keyboard Settings") {
                    model.openKeyboardSettings()
                }
                .buttonStyle(.borderedProminent)

                Text("In Keyboard settings, change “Press Globe key to” from “Change Input Source” to “Do Nothing”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .permissions:
            permissionSetup
        case .actions:
            VStack(alignment: .leading, spacing: 12) {
                Picker("Single press", selection: sourceBinding(\.singlePress)) {
                    sourceOptions
                }
                Picker("Double press", selection: sourceBinding(\.doublePress)) {
                    sourceOptions
                }
                Picker("Triple press", selection: sourceBinding(\.triplePress)) {
                    sourceOptions
                }

                Button("Use Suggested Mapping") {
                    model.applyRecommendedInputSourceMapping()
                }
            }
            .frame(maxWidth: 420)
        case .ready:
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch Globe at login", isOn: launchAtLoginBinding)
                Toggle("Show switching HUD", isOn: showHUDBinding)
                Toggle("Enable Globe", isOn: enabledBinding)
            }
            .frame(maxWidth: 360)
        case .intro, .privacy:
            EmptyView()
        }
    }

    private var footer: some View {
        HStack {
            Text("Step \(step + 1) of \(steps.count)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Back") {
                step = max(0, step - 1)
            }
            .disabled(step == 0)

            if step < steps.count - 1 {
                Button("Continue") {
                    step += 1
                }
                .keyboardShortcut(.defaultAction)
                .disabled(steps[step].kind == .permissions && !model.inputMonitoringTrusted)
            } else {
                Button("Start Using Globe") {
                    model.completeOnboarding()
                    model.closeOnboarding()
                    model.showLaunchStatusWindow()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var permissionSetup: some View {
        #if GLOBE_APP_STORE
        EmptyView()
        #else
        VStack(alignment: .leading, spacing: 14) {
            Label(
                model.inputMonitoringTrusted ? "Fn/Globe monitoring is ready." : "Input Monitoring is required to detect Globe/Fn.",
                systemImage: model.inputMonitoringTrusted ? "checkmark.circle.fill" : "lock.open"
            )
            .font(.callout)
            .foregroundStyle(model.inputMonitoringTrusted ? .green : .secondary)

            if model.inputMonitoringTrusted {
                Text("Input Monitoring is enabled. Globe can now receive the global Fn/Globe events used for switching outside Globe focus.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Button("Request Input Monitoring") {
                    model.beginInputMonitoringSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Globe asks macOS for access automatically. After Globe appears in Input Monitoring, turn it on and restart Globe. If it still says Needed, remove and add Globe again in System Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("Restart Globe") {
                        model.restartApp()
                    }

                    Button("Show Globe in Finder") {
                        model.revealAppInFinder()
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .frame(maxWidth: 480, alignment: .leading)
        #endif
    }

    private func statusPill(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var sourceOptions: some View {
        Text("Do nothing").tag(CodableGlobePressAction.none)

        ForEach(model.inputSources) { source in
            Text(source.localizedName).tag(CodableGlobePressAction.inputSource(id: source.id))
        }
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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLogin },
            set: {
                model.settings.launchAtLogin = $0
                model.saveSettings()
            }
        )
    }

    private var showHUDBinding: Binding<Bool> {
        Binding(
            get: { model.settings.showSwitchingHUD },
            set: {
                model.settings.showSwitchingHUD = $0
                model.saveSettings()
            }
        )
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
}

private struct OnboardingStep {
    let kind: OnboardingStepKind
    let icon: String
    let title: String
    let subtitle: String
    let body: String
}

private enum OnboardingStepKind {
    case intro
    case privacy
    case keyboardSetup
    case permissions
    case actions
    case ready
}
