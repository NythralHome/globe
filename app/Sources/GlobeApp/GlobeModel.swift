import AppKit
import Combine
import Foundation
import GlobeCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class GlobeModel: ObservableObject {
    @Published var settings: GlobeSettings
    @Published private(set) var currentInputSourceName = "Unknown"
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var inputSources: [InputSource] = []
    @Published private(set) var lastGlobeKeyTestEvent = "Press Globe/Fn to test key detection."

    private let settingsStore: SettingsStoring
    private let permissionManager: PermissionManaging
    private let inputSourceManager: InputSourceManaging
    private let hudController = HUDController()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private var pressInterpreter: GlobePressInterpreter
    private var pendingTimer: Timer?
    private var updateCheckTask: Task<Void, Never>?
    private var updateDownloadTask: Task<Void, Never>?
    private var onboardingWindow: NSWindow?
    private var onboardingWindowDelegate: OnboardingWindowDelegate?
    private var settingsWindow: NSWindow?
    private var settingsWindowDelegate: SettingsWindowDelegate?
    private var launchStatusWindow: NSWindow?
    private var launchStatusWindowDelegate: LaunchStatusWindowDelegate?
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
        let isTrusted = permissionManager.requestAccessibilityPermission()
        if !isTrusted {
            keyboardMonitor.start()
        }
        refreshSystemState()
        startKeyboardMonitor()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }

            refreshSystemState()
            if accessibilityTrusted {
                startKeyboardMonitor()
            }
        }
    }

    func beginAccessibilitySetup() {
        requestAccessibilityPermission()
    }

    func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func openAccessibilitySettings() {
        SystemSettingsOpener.openAccessibility()
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
        lastGlobeKeyTestEvent = "Press Globe/Fn to test key detection."
    }

    func exportDiagnostics() {
        refreshSystemState()

        let savePanel = NSSavePanel()
        savePanel.title = "Export Globe Diagnostics"
        savePanel.nameFieldStringValue = "Globe-Diagnostics-\(Self.diagnosticsTimestamp()).txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return
        }

        do {
            try diagnosticsReport().write(to: url, atomically: true, encoding: .utf8)
            DiagnosticLogger.log("Exported diagnostics to \(url.path)")
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            DiagnosticLogger.log("Failed to export diagnostics: \(error.localizedDescription)")
            showDiagnosticsExportError(error)
        }
    }

    func checkForUpdates() {
        if AppDistribution.isAppStore {
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
            showSettingsWindow()
        case .showInputSourcePicker:
            break
        case .none:
            break
        }
    }

    private func recordGlobeKeyTestEvent(_ input: GlobePressInterpreter.Input) {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        switch input {
        case let .keyDown(date):
            lastGlobeKeyTestEvent = "Detected Globe/Fn down at \(formatter.string(from: date))."
        case let .keyUp(date):
            lastGlobeKeyTestEvent = "Detected Globe/Fn up at \(formatter.string(from: date))."
        case .timer:
            break
        }
    }

    private func startKeyboardMonitor() {
        guard settings.isEnabled else {
            return
        }

        guard accessibilityTrusted else {
            DiagnosticLogger.log("KeyboardMonitor.start skipped; Accessibility permission is missing")
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

    private func scheduleLongPressTimeout() {
        pendingTimer?.invalidate()
        pendingTimer = Timer.scheduledTimer(withTimeInterval: settings.timing.longPressDuration + 0.02, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handlePressInput(.timer(Date()))
            }
        }
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

    private func showDiagnosticsExportError(_ error: Error) {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = "Could not export diagnostics"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func diagnosticsReport() -> String {
        let inputSourceLines = inputSources
            .map { "- \($0.localizedName) (`\($0.id)`)" }
            .joined(separator: "\n")
        let mapping = settings.mapping

        return """
        Globe Diagnostics
        =================

        Generated: \(ISO8601DateFormatter().string(from: Date()))
        Globe version: \(AppVersion.displayString)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Accessibility trusted: \(accessibilityTrusted)
        Current input source: \(currentInputSourceName)
        Launch at login: \(settings.launchAtLogin)
        Globe enabled: \(settings.isEnabled)
        Show menu bar icon: \(settings.showMenuBarIcon)
        Show switching HUD: \(settings.showSwitchingHUD)
        Multi-press timeout: \(settings.timing.multiPressTimeout)
        Long-press duration: \(settings.timing.longPressDuration)

        Mapping
        -------
        Single press: \(mapping.singlePress)
        Double press: \(mapping.doublePress)
        Triple press: \(mapping.triplePress)
        Long press: \(mapping.longPress)

        Installed input sources
        -----------------------
        \(inputSourceLines.isEmpty ? "No input sources detected." : inputSourceLines)

        Recent Globe log
        ----------------
        \(DiagnosticLogger.recentLog())
        """
    }

    private static func diagnosticsTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
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
