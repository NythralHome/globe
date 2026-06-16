import AppKit
import Combine
import Foundation
import GlobeCore
import SwiftUI

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
    private var onboardingWindow: NSWindow?
    private var onboardingWindowDelegate: OnboardingWindowDelegate?
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

        DiagnosticLogger.log("GlobeModel.init enabled=\(settings.isEnabled) timing=\(settings.timing)")
        refreshSystemState()
        startKeyboardMonitor()

        if !settings.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak self] in
                self?.showOnboarding()
            }
        }
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
        DiagnosticLogger.log("refreshSystemState accessibilityTrusted=\(accessibilityTrusted) current=\(currentInputSourceName) sources=\(inputSources.map(\.localizedName).joined(separator: ","))")
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

    func enableLaunchAtLogin() {
        settings.launchAtLogin = true
        saveSettings()
        refreshSystemState()
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        settings.isEnabled = true
        settingsStore.save(settings)
        startKeyboardMonitor()
    }

    func applyRecommendedInputSourceMapping() {
        let sources = inputSources
        settings.mapping.singlePress = sources[safe: 0].map { .inputSource(id: $0.id) } ?? .none
        settings.mapping.doublePress = sources[safe: 1].map { .inputSource(id: $0.id) } ?? .none
        settings.mapping.triplePress = sources[safe: 2].map { .inputSource(id: $0.id) } ?? .none
        settings.mapping.longPress = .openSettings
        saveSettings()
    }

    func showOnboarding() {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let hostingController = NSHostingController(
            rootView: OnboardingView(model: self)
                .frame(width: 820, height: 540)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 820, height: 540)
        window.maxSize = NSSize(width: 820, height: 540)
        window.title = "Welcome to Globe"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
        let delegate = OnboardingWindowDelegate { [weak self] in
            self?.onboardingWindow = nil
            self?.onboardingWindowDelegate = nil
        }
        window.delegate = delegate
        onboardingWindowDelegate = delegate
        onboardingWindow = window
    }

    func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func handlePressInput(_ input: GlobePressInterpreter.Input) {
        guard settings.isEnabled else {
            DiagnosticLogger.log("handlePressInput ignored; Globe disabled")
            return
        }

        let interpretedActions = pressInterpreter.handle(input)
        DiagnosticLogger.log("handlePressInput input=\(input) actions=\(interpretedActions)")
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
                DiagnosticLogger.log("perform inputSource failed; source not found id=\(id)")
                return
            }

            do {
                try inputSourceManager.selectInputSource(id: id)
                DiagnosticLogger.log("perform inputSource selected id=\(id) name=\(selectedSource.localizedName)")
            } catch {
                DiagnosticLogger.log("perform inputSource failed id=\(id) error=\(error)")
            }
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

private final class OnboardingWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
