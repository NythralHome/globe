import AppKit
import Combine
import Foundation
import GlobeCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class GlobeModel: ObservableObject {
    // The single, app-wide instance. GlobeModel.init starts a global HID monitor,
    // so there must only ever be one; see GlobeApp for why @StateObject can
    // otherwise create throwaway instances.
    static let shared = GlobeModel()

    @Published var settings: GlobeSettings
    @Published private(set) var currentInputSourceName = "Unknown"
    @Published private(set) var inputMonitoringTrusted = false
    @Published private(set) var inputSources: [InputSource] = []
    @Published private(set) var lastGlobeKeyTestEvent = "Press Globe/Fn to test key detection."

    private let settingsStore: SettingsStoring
    private let permissionManager: PermissionManaging
    private let inputSourceManager: InputSourceManaging
    private let hudController = HUDController()
    #if !GLOBE_APP_STORE
    private let textLayoutFixer = TextLayoutFixer()
    #endif
    private let launchAtLoginManager = LaunchAtLoginManager()
    private var pressInterpreter: GlobePressInterpreter
    private var pendingPressWorkItem: DispatchWorkItem?
    private var updateCheckTask: Task<Void, Never>?
    private var updateDownloadTask: Task<Void, Never>?
    private var onboardingWindow: NSWindow?
    private var onboardingWindowDelegate: OnboardingWindowDelegate?
    private var settingsWindow: NSWindow?
    private var settingsWindowDelegate: SettingsWindowDelegate?
    private var launchStatusWindow: NSWindow?
    private var launchStatusWindowDelegate: LaunchStatusWindowDelegate?
    private lazy var keyboardMonitor = KeyboardMonitor { [weak self] trigger in
        self?.handleKeyboardTrigger(trigger)
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
        #if GLOBE_APP_STORE
        self.lastGlobeKeyTestEvent = "Press \(settings.appStoreShortcut.displayName) to test shortcut detection."
        #endif

        DiagnosticLogger.log("GlobeModel.init enabled=\(settings.isEnabled) timing=\(settings.timing)")
        refreshSystemState()
        startKeyboardMonitor()

        DispatchQueue.main.async { [weak self] in
            if settings.hasCompletedOnboarding {
                self?.showLaunchStatusWindow()
            } else {
                self?.showOnboarding()
            }
        }
    }

    func saveSettings() {
        try? launchAtLoginManager.setEnabled(settings.launchAtLogin)
        settingsStore.save(settings)
        pressInterpreter = GlobePressInterpreter(timing: settings.timing)
        stopKeyboardMonitor()

        if settings.isEnabled {
            startKeyboardMonitor()
        }
    }

    func refreshSystemState() {
        inputMonitoringTrusted = permissionManager.isInputMonitoringTrusted
        inputSources = inputSourceManager.availableInputSources()
        currentInputSourceName = inputSourceManager.currentInputSource()?.localizedName ?? "Unknown"
        settings.launchAtLogin = launchAtLoginManager.isEnabled
        #if GLOBE_APP_STORE
        DiagnosticLogger.log("refreshSystemState current=\(currentInputSourceName) sources=\(inputSources.map(\.localizedName).joined(separator: ","))")
        #else
        DiagnosticLogger.log("refreshSystemState inputMonitoringTrusted=\(inputMonitoringTrusted) current=\(currentInputSourceName) sources=\(inputSources.map(\.localizedName).joined(separator: ","))")
        #endif
    }

    func requestInputMonitoringPermission() {
        #if GLOBE_APP_STORE
        refreshSystemState()
        startKeyboardMonitor()
        #else
        let isTrusted = permissionManager.requestInputMonitoringPermission()
        DiagnosticLogger.log("requestInputMonitoringPermission returned=\(isTrusted)")
        refreshSystemState()
        DiagnosticLogger.log("requestInputMonitoringPermission afterRefresh inputMonitoringTrusted=\(inputMonitoringTrusted)")
        startKeyboardMonitor()

        if !inputMonitoringTrusted {
            SystemSettingsOpener.openInputMonitoring()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }

            refreshSystemState()
            DiagnosticLogger.log("requestInputMonitoringPermission delayedRefresh inputMonitoringTrusted=\(inputMonitoringTrusted)")
            if inputMonitoringTrusted {
                startKeyboardMonitor()
            } else {
                SystemSettingsOpener.openInputMonitoring()
            }
        }
        #endif
    }

    func beginInputMonitoringSetup() {
        requestInputMonitoringPermission()
    }

    func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func openInputMonitoringSettings() {
        SystemSettingsOpener.openInputMonitoring()
    }

    func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", bundleURL.path]

        do {
            try process.run()
            AppDelegate.allowTermination()
            NSApplication.shared.terminate(nil)
        } catch {
            DiagnosticLogger.log("Failed to restart Globe: \(error.localizedDescription)")
            refreshSystemState()
        }
    }

    func openKeyboardSettings() {
        SystemSettingsOpener.openKeyboard()
    }

    func openWebsite() {
        NSWorkspace.shared.open(AppLinks.website)
    }

    func openAuthorWebsite() {
        NSWorkspace.shared.open(AppLinks.authorWebsite)
    }

    func openRepository() {
        NSWorkspace.shared.open(AppLinks.repository)
    }

    func reportIssue() {
        NSWorkspace.shared.open(AppLinks.issues)
    }

    func resetGlobeKeyTest() {
        lastGlobeKeyTestEvent = AppDistribution.capturesGlobeKey ? "Press Globe/Fn to test key detection." : "Press your shortcut to test detection."
    }

    func checkForUpdates() {
        guard AppDistribution.usesInAppUpdates else {
            showAppStoreUpdateInformation()
            return
        }

        updateCheckTask?.cancel()
        updateCheckTask = Task { [weak self] in
            do {
                let result = try await UpdateChecker.check()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.showUpdateResult(result)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.showUpdateError(error)
                }
            }
        }
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
            presentWindowCentered(onboardingWindow)
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
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 820, height: 540)
        window.maxSize = NSSize(width: 820, height: 540)
        window.title = "Welcome to Globe"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        presentWindowCentered(window)
        let delegate = OnboardingWindowDelegate { [weak self] in
            self?.onboardingWindow = nil
            self?.onboardingWindowDelegate = nil
        }
        window.delegate = delegate
        onboardingWindowDelegate = delegate
        onboardingWindow = window
    }

    func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
        onboardingWindow = nil
        onboardingWindowDelegate = nil
    }

    func showSettingsWindow() {
        if let settingsWindow {
            presentWindowCentered(settingsWindow)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(model: self)
                .frame(width: 780, height: 520)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 780, height: 520)
        window.title = "Globe Settings"
        presentWindowCentered(window)

        let delegate = SettingsWindowDelegate { [weak self] in
            self?.settingsWindow = nil
            self?.settingsWindowDelegate = nil
        }
        window.delegate = delegate
        settingsWindowDelegate = delegate
        settingsWindow = window
    }

    func showLaunchStatusWindow() {
        if let launchStatusWindow {
            presentWindowCentered(launchStatusWindow)
            return
        }

        let hostingController = NSHostingController(
            rootView: LaunchStatusView(
                openSettings: { [weak self] in
                    self?.closeLaunchStatusWindow()
                    self?.showSettingsWindow()
                },
                close: { [weak self] in
                    self?.closeLaunchStatusWindow()
                }
            )
            .frame(width: 460, height: 250)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 460, height: 250)
        window.maxSize = NSSize(width: 460, height: 250)
        window.title = "Globe is Running"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        presentWindowCentered(window)

        let delegate = LaunchStatusWindowDelegate { [weak self] in
            self?.launchStatusWindow = nil
            self?.launchStatusWindowDelegate = nil
        }
        window.delegate = delegate
        launchStatusWindowDelegate = delegate
        launchStatusWindow = window
    }

    private func closeLaunchStatusWindow() {
        launchStatusWindow?.orderOut(nil)
        launchStatusWindow = nil
        launchStatusWindowDelegate = nil
    }

    func handlePressInput(_ input: GlobePressInterpreter.Input) {
        recordGlobeKeyTestEvent(input)

        guard settings.isEnabled else {
            DiagnosticLogger.log("handlePressInput ignored; Globe disabled")
            return
        }

        let interpretedActions = pressInterpreter.handle(input)
        DiagnosticLogger.log("handlePressInput input=\(input) actions=\(interpretedActions)")
        for interpretedAction in interpretedActions {
            perform(settings.mapping.mapping.action(for: interpretedAction))
        }

        switch input {
        case .keyDown:
            scheduleLongPressTimeout()
        case .keyUp:
            schedulePendingPressTimeout()
        case .timer:
            break
        }
    }

    func handleKeyboardTrigger(_ trigger: KeyboardTrigger) {
        switch trigger {
        case let .press(input):
            handlePressInput(input)
        case let .inputSource(id):
            #if GLOBE_APP_STORE
            switchDirectlyToInputSource(id: id, fixingSelectedText: false)
            #else
            switchDirectlyToInputSource(id: id, fixingSelectedText: true)
            #endif
        }
    }

    private func perform(_ action: GlobePressAction) {
        switch action {
        case let .inputSource(id):
            switchDirectlyToInputSource(id: id, fixingSelectedText: false)
        case .openSettings:
            showSettingsWindow()
        case .showInputSourcePicker:
            break
        case .none:
            break
        }
    }

    private func switchDirectlyToInputSource(id: String, fixingSelectedText: Bool) {
        guard let selectedSource = inputSources.first(where: { $0.id == id }) else {
            DiagnosticLogger.log("perform inputSource failed; source not found id=\(id)")
            return
        }

        #if GLOBE_APP_STORE
        selectInputSource(selectedSource)
        #else
        if fixingSelectedText {
            textLayoutFixer.fixSelectedText(targetSource: selectedSource) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case let .fixed(text):
                        DiagnosticLogger.log("Fixed selected text as \(selectedSource.localizedName) length=\(text.count)")
                    case .noSelection:
                        DiagnosticLogger.log("Fix selected text skipped; no text selection")
                    case let .failed(message):
                        DiagnosticLogger.log("Fix selected text failed: \(message)")
                    }

                    self?.selectInputSource(selectedSource)
                }
            }
        } else {
            selectInputSource(selectedSource)
        }
        #endif
    }

    private func selectInputSource(_ selectedSource: InputSource) {
        do {
            try inputSourceManager.selectInputSource(id: selectedSource.id)
            DiagnosticLogger.log("perform inputSource selected id=\(selectedSource.id) name=\(selectedSource.localizedName)")
        } catch {
            DiagnosticLogger.log("perform inputSource failed id=\(selectedSource.id) error=\(error)")
        }
        refreshSystemState()
        if settings.showSwitchingHUD {
            hudController.show(text: selectedSource.localizedName)
        }
    }

    private func recordGlobeKeyTestEvent(_ input: GlobePressInterpreter.Input) {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        switch input {
        case let .keyDown(date):
            #if GLOBE_APP_STORE
            lastGlobeKeyTestEvent = "Detected shortcut at \(formatter.string(from: date))."
            #else
            lastGlobeKeyTestEvent = "Detected Globe/Fn down at \(formatter.string(from: date))."
            #endif
        case let .keyUp(date):
            #if GLOBE_APP_STORE
            lastGlobeKeyTestEvent = "Completed shortcut at \(formatter.string(from: date))."
            #else
            lastGlobeKeyTestEvent = "Detected Globe/Fn up at \(formatter.string(from: date))."
            #endif
        case .timer:
            break
        }
    }

    private func startKeyboardMonitor() {
        guard settings.isEnabled else {
            return
        }

        keyboardMonitor.configureAppStoreShortcuts(
            actionShortcut: settings.appStoreShortcut,
            inputSourceShortcuts: settings.appStoreInputSourceShortcuts
        )

        #if GLOBE_APP_STORE
        keyboardMonitor.start()
        #else
        keyboardMonitor.start()
        #endif
    }

    private func stopKeyboardMonitor() {
        pendingPressWorkItem?.cancel()
        pendingPressWorkItem = nil
        keyboardMonitor.stop()
        pressInterpreter.reset()
    }

    private func schedulePendingPressTimeout() {
        schedulePressTimeout(after: settings.timing.multiPressTimeout + 0.02)
    }

    private func scheduleLongPressTimeout() {
        schedulePressTimeout(after: settings.timing.longPressDuration + 0.02)
    }

    private func schedulePressTimeout(after delay: TimeInterval) {
        pendingPressWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.handlePressInput(.timer(Date()))
            }
        }
        pendingPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func presentWindowCentered(_ window: NSWindow) {
        centerWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            self.centerWindow(window)
        }
    }

    private func centerWindow(_ window: NSWindow) {
        window.contentView?.layoutSubtreeIfNeeded()

        let screen = screenForPresentation()
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let frame = window.frame
        let origin = NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.midY - frame.height / 2
        )
        window.setFrameOrigin(origin)
    }

    private func screenForPresentation() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return mouseScreen
        }

        return NSApplication.shared.keyWindow?.screen
            ?? NSApplication.shared.mainWindow?.screen
            ?? NSScreen.main
    }

    private func showUpdateResult(_ result: UpdateCheckResult) {
        NSApplication.shared.activate()
        let alert = NSAlert()

        switch result {
        case let .upToDate(release):
            alert.messageText = "Globe is up to date"
            alert.informativeText = "You are running \(AppVersion.versionString). Latest release: \(release.tagName)."
            alert.addButton(withTitle: "OK")
        case let .updateAvailable(release):
            alert.messageText = "A new Globe version is available"
            alert.informativeText = updateMessage(for: release)
            alert.addButton(withTitle: release.installerAsset == nil ? "Open Releases" : "Download Installer")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                downloadAndOpenUpdateInstaller(from: release)
            }
            return
        }

        alert.runModal()
    }

    private func showAppStoreUpdateInformation() {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = "Globe updates through the Mac App Store"
        alert.informativeText = "This build of Globe is installed and updated by the Mac App Store. Open the App Store to check for updates."
        alert.addButton(withTitle: "Open App Store")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
        }
    }

    private func downloadAndOpenUpdateInstaller(from release: ReleaseInfo) {
        guard release.installerAsset != nil else {
            NSWorkspace.shared.open(release.htmlURL)
            return
        }

        updateDownloadTask?.cancel()
        updateDownloadTask = Task { [weak self] in
            do {
                let installerURL = try await UpdateChecker.downloadInstaller(from: release)
                await MainActor.run {
                    self?.showDownloadedInstaller(installerURL)
                }
            } catch {
                await MainActor.run {
                    self?.showUpdateDownloadError(error, fallbackURL: release.htmlURL)
                }
            }
        }
    }

    private func showDownloadedInstaller(_ installerURL: URL) {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = "Globe installer downloaded"
        alert.informativeText = """
        The signed installer was saved to Downloads.

        Open it now to install the update. After installation, Globe will restart from Applications.
        """
        alert.addButton(withTitle: "Open Installer")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(installerURL)
        }
    }

    private func showUpdateDownloadError(_ error: Error, fallbackURL: URL) {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = "Could not download update"
        alert.informativeText = "Globe could not download the signed installer. You can still open the GitHub release page.\n\n\(error.localizedDescription)"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Release")

        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    private func showUpdateError(_ error: Error) {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = "Could not check for updates"
        alert.informativeText = "Globe could not reach GitHub Releases. Check your connection and try again.\n\n\(error.localizedDescription)"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Releases")

        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(AppLinks.releases)
        }
    }

    private func updateMessage(for release: ReleaseInfo) -> String {
        let title = release.name ?? release.tagName
        let body = release.body?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", maxSplits: 8)
            .joined(separator: "\n")

        if let body, !body.isEmpty {
            return "Installed: \(AppVersion.versionString)\nAvailable: \(title)\n\nWhat's new:\n\(body)"
        }

        return "Installed: \(AppVersion.versionString)\nAvailable: \(title)\n\nDownload the signed installer to update Globe."
    }
}

private final class OnboardingWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: @MainActor () -> Void

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        Task { @MainActor [onClose] in
            onClose()
        }
        return false
    }
}

private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: @MainActor () -> Void

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        Task { @MainActor [onClose] in
            onClose()
        }
        return false
    }
}

private final class LaunchStatusWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: @MainActor () -> Void

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        Task { @MainActor [onClose] in
            onClose()
        }
        return false
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
