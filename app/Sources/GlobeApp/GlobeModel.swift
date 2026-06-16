import AppKit
import Combine
import Foundation
import GlobeCore

@MainActor
final class GlobeModel: ObservableObject {
    @Published var settings: GlobeSettings
    @Published private(set) var currentInputSourceName = "Unknown"
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var inputSources: [InputSource] = []

    private let settingsStore: SettingsStoring
    private let permissionManager: PermissionManaging
    private let inputSourceManager: InputSourceManaging
    private let hudController = HUDController()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private var pressInterpreter: GlobePressInterpreter
    private var pendingTimer: Timer?
    private lazy var keyboardMonitor = KeyboardMonitor { [weak self] input in
        self?.handlePressInput(input)
    }

    init(
        settingsStore: SettingsStoring = SettingsStore(),
        permissionManager: PermissionManaging = PermissionManager(),
        inputSourceManager: InputSourceManaging = InputSourceManager()
    ) {
        self.settingsStore = settingsStore
        self.permissionManager = permissionManager
        self.inputSourceManager = inputSourceManager

        let settings = settingsStore.load()
        self.settings = settings
        self.pressInterpreter = GlobePressInterpreter(timing: settings.timing)

        refreshSystemState()
        startKeyboardMonitor()
    }

    func saveSettings() {
        try? launchAtLoginManager.setEnabled(settings.launchAtLogin)
        settingsStore.save(settings)
        pressInterpreter = GlobePressInterpreter(timing: settings.timing)

        if settings.isEnabled {
            startKeyboardMonitor()
        } else {
            stopKeyboardMonitor()
        }
    }

    func refreshSystemState() {
        accessibilityTrusted = permissionManager.isAccessibilityTrusted
        inputSources = inputSourceManager.availableInputSources()
        currentInputSourceName = inputSourceManager.currentInputSource()?.localizedName ?? "Unknown"
        settings.launchAtLogin = launchAtLoginManager.isEnabled
    }

    func requestAccessibilityPermission() {
        permissionManager.requestAccessibilityPermission()
        refreshSystemState()
    }

    func openAccessibilitySettings() {
        SystemSettingsOpener.openAccessibility()
    }

    func openKeyboardSettings() {
        SystemSettingsOpener.openKeyboard()
    }

    func handlePressInput(_ input: GlobePressInterpreter.Input) {
        guard settings.isEnabled else {
            return
        }

        let interpretedActions = pressInterpreter.handle(input)
        for interpretedAction in interpretedActions {
            perform(settings.mapping.mapping.action(for: interpretedAction))
        }

        if case .keyUp = input {
            schedulePendingPressTimeout()
        }
    }

    private func perform(_ action: GlobePressAction) {
        switch action {
        case let .inputSource(id):
            guard let selectedSource = inputSources.first(where: { $0.id == id }) else {
                return
            }

            try? inputSourceManager.selectInputSource(id: id)
            refreshSystemState()
            if settings.showSwitchingHUD {
                hudController.show(text: selectedSource.localizedName)
            }
        case .openSettings:
            NSApplication.shared.activate()
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case .showInputSourcePicker:
            break
        case .none:
            break
        }
    }

    private func startKeyboardMonitor() {
        guard settings.isEnabled else {
            return
        }

        keyboardMonitor.start()
    }

    private func stopKeyboardMonitor() {
        pendingTimer?.invalidate()
        pendingTimer = nil
        keyboardMonitor.stop()
        pressInterpreter.reset()
    }

    private func schedulePendingPressTimeout() {
        pendingTimer?.invalidate()
        pendingTimer = Timer.scheduledTimer(withTimeInterval: settings.timing.multiPressTimeout + 0.02, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handlePressInput(.timer(Date()))
            }
        }
    }
}
