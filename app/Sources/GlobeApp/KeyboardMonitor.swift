import AppKit
import CoreGraphics
import Foundation
import GlobeCore
import Carbon.HIToolbox

enum KeyboardTrigger: Sendable {
    case press(GlobePressInterpreter.Input)
    /// Something other than a clean Globe press happened: another key or a
    /// media key while Globe is down (a chord such as Globe+arrow), or typing
    /// during the wait between presses. The interpreter drops its pending
    /// count instead of switching the layout.
    case cancel
    case inputSource(id: String)
}

final class KeyboardMonitor: @unchecked Sendable {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var appStoreShortcut: CodableKeyboardShortcut = .controlOptionZ
    private var appStoreInputSourceShortcuts: [String: CodableKeyboardShortcut] = [:]
    private var hotKeyActions: [UInt32: KeyboardTrigger] = [:]
    private var hotKeysAreStarted = false
    #if GLOBE_APP_STORE
    #else
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventTapRunLoop: CFRunLoop?
    private var eventTapThread: Thread?
    private let eventTapLock = NSLock()
    #endif
    private var isFunctionKeyPressed = false
    /// The press in progress started as a chord (Globe held together with
    /// another key, modifier or a media key), so its release must not reach
    /// the interpreter as a key up.
    private var chordedPress = false
    private let handler: @MainActor (KeyboardTrigger) -> Void

    init(handler: @escaping @MainActor (KeyboardTrigger) -> Void) {
        self.handler = handler
    }

    func configureAppStoreShortcuts(
        actionShortcut: CodableKeyboardShortcut,
        inputSourceShortcuts: [String: CodableKeyboardShortcut]
    ) {
        appStoreShortcut = actionShortcut
        appStoreInputSourceShortcuts = inputSourceShortcuts
    }

    func start(enableEventTap: Bool = true) {
        startHotKeys()

        #if !GLOBE_APP_STORE
        if enableEventTap {
            startEventTap()
        } else {
            DiagnosticLogger.log("KeyboardMonitor.start skipped HID event tap; Input Monitoring is missing")
            stopEventTap()
        }
        #endif
    }

    func stop() {
        DiagnosticLogger.log("KeyboardMonitor.stop")
        stopHotKeys()
        #if !GLOBE_APP_STORE
        stopEventTap()
        #endif
        isFunctionKeyPressed = false
        chordedPress = false
    }

    private func startHotKeys() {
        guard !hotKeysAreStarted else {
            DiagnosticLogger.log("KeyboardMonitor.start ignored; hotkeys already exist")
            return
        }

        DiagnosticLogger.log("KeyboardMonitor.start hotkeys")
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]
        let target = GetApplicationEventTarget()
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            target,
            { _, event, refcon in
                guard let refcon else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return noErr
                }

                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleAppStoreHotKey(id: hotKeyID.id, eventKind: GetEventKind(event))
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            refcon,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            DiagnosticLogger.log("KeyboardMonitor.start failed; InstallEventHandler status=\(handlerStatus)")
            return
        }

        registerAppStoreHotKeys(target: target)

        guard !hotKeyRefs.isEmpty else {
            removeAppStoreEventHandler()
            return
        }

        hotKeysAreStarted = true
    }

    private func stopHotKeys() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefs = []
        hotKeyActions = [:]
        hotKeysAreStarted = false
        removeAppStoreEventHandler()
    }

    #if !GLOBE_APP_STORE
    private func startEventTap() {
        eventTapLock.lock()
        let isAlreadyStarted = eventTapThread != nil || eventTap != nil
        eventTapLock.unlock()

        guard !isAlreadyStarted else {
            DiagnosticLogger.log("KeyboardMonitor.start ignored; event tap already exists")
            return
        }

        DiagnosticLogger.log("KeyboardMonitor.start event tap thread")
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.runEventTapThread(ready: ready)
        }
        thread.name = "Globe HID Event Tap"

        eventTapLock.lock()
        eventTapThread = thread
        eventTapLock.unlock()

        thread.start()

        if ready.wait(timeout: .now() + 1.0) == .timedOut {
            DiagnosticLogger.log("KeyboardMonitor.start event tap thread did not report ready within 1s")
        }
    }

    private func runEventTapThread(ready: DispatchSemaphore) {
        DiagnosticLogger.log("KeyboardMonitor.start")
        // Beyond the fn flag transitions, the tap watches other key activity
        // so chords and typing can cancel a pending press. It stays
        // listen-only: no event is ever swallowed.
        var mask = (1 << CGEventType.flagsChanged.rawValue)
        mask |= (1 << CGEventType.keyDown.rawValue)
        mask |= (1 << CGEventType.keyUp.rawValue)
        mask |= (1 << Self.systemDefinedEventType)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    monitor.enableEventTap()
                }
                return Unmanaged.passUnretained(event)
            }

            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
            _ = monitor.handle(type: type, event: event)

            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        ) else {
            DiagnosticLogger.log("KeyboardMonitor.start failed; CGEvent.tapCreate returned nil")
            eventTapLock.lock()
            eventTapThread = nil
            eventTapLock.unlock()
            ready.signal()
            return
        }

        let currentRunLoop = CFRunLoopGetCurrent()
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        eventTapLock.lock()
        eventTap = tap
        runLoopSource = source
        eventTapRunLoop = currentRunLoop
        eventTapLock.unlock()

        if let source {
            CFRunLoopAddSource(currentRunLoop, source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        DiagnosticLogger.log("KeyboardMonitor.start created HID event tap")
        ready.signal()

        CFRunLoopRun()
    }

    private func stopEventTap() {
        eventTapLock.lock()
        let runLoop = eventTapRunLoop
        let source = runLoopSource
        let tap = eventTap
        eventTapLock.unlock()

        guard let runLoop else {
            eventTapLock.lock()
            runLoopSource = nil
            eventTap = nil
            eventTapThread = nil
            eventTapLock.unlock()
            return
        }

        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in
            if let source {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }

            if let tap {
                CGEvent.tapEnable(tap: tap, enable: false)
                CFMachPortInvalidate(tap)
            }

            guard let self else {
                CFRunLoopStop(CFRunLoopGetCurrent())
                return
            }

            self.eventTapLock.lock()
            self.runLoopSource = nil
            self.eventTap = nil
            self.eventTapRunLoop = nil
            self.eventTapThread = nil
            self.eventTapLock.unlock()

            CFRunLoopStop(CFRunLoopGetCurrent())
        }

        CFRunLoopWakeUp(runLoop)
    }

    private func enableEventTap() {
        eventTapLock.lock()
        let tap = eventTap
        eventTapLock.unlock()

        guard let tap else {
            return
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        DiagnosticLogger.log("KeyboardMonitor re-enabled event tap")
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard let trigger = keyboardTrigger(for: type, event: event) else {
            return false
        }

        let handler = handler
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(trigger)
            }
        }

        return true
    }

    /// Reduces one tap event to the trigger it means for the interpreter, or
    /// nil when the event cannot affect a gesture. The tap never swallows
    /// anything: chords and typing merely cancel pending presses instead of
    /// counting as them.
    private func keyboardTrigger(for type: CGEventType, event: CGEvent) -> KeyboardTrigger? {
        switch type {
        case .flagsChanged:
            return flagsChangedTrigger(event)
        case .keyDown, .keyUp:
            // Releasing the Globe key makes macOS synthesize a keyDown/keyUp
            // pair with the Globe key's own keycode in the same millisecond
            // as the flagsChanged that reports the release. It is an echo of
            // the press just counted, not typing; feeding it onward would
            // cancel every finished press before it can fire.
            guard event.getIntegerValueField(.keyboardEventKeycode) != Self.syntheticGlobeKeycode else {
                return nil
            }
            return otherKeyEventTrigger()
        default:
            guard type.rawValue == Self.systemDefinedEventType else {
                return nil
            }
            return otherKeyEventTrigger()
        }
    }

    private func flagsChangedTrigger(_ event: CGEvent) -> KeyboardTrigger? {
        let hasFunctionFlag = event.flags.contains(.maskSecondaryFn)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        DiagnosticLogger.log("flagsChanged keyCode=\(keyCode) flags=\(event.flags.rawValue) hasFunctionFlag=\(hasFunctionFlag)")

        guard hasFunctionFlag != isFunctionKeyPressed else {
            // Another modifier changed while the Globe key sits still: a
            // hold that now carries a modifier is a chord, not a gesture.
            if isFunctionKeyPressed {
                chordedPress = true
                return .cancel
            }
            return nil
        }

        isFunctionKeyPressed = hasFunctionFlag

        if hasFunctionFlag {
            // A press that starts with a real modifier held (Cmd+Globe,
            // Ctrl+Globe) is a shortcut chord, not a gesture.
            let hasPrimaryModifier = event.flags.contains(.maskCommand)
                || event.flags.contains(.maskControl)
                || event.flags.contains(.maskAlternate)
                || event.flags.contains(.maskShift)
            if hasPrimaryModifier {
                chordedPress = true
                return .cancel
            }

            chordedPress = false
            DiagnosticLogger.log("KeyboardMonitor interpreted keyDown")
            return .press(.keyDown(Date()))
        }

        if chordedPress {
            chordedPress = false
            DiagnosticLogger.log("KeyboardMonitor chord canceled press")
            return .cancel
        }

        DiagnosticLogger.log("KeyboardMonitor interpreted keyUp")
        return .press(.keyUp(Date()))
    }

    /// Any other key or media-key activity. While the Globe key is down this
    /// turns the hold into a chord (Globe+arrow for Home/End, Globe+brightness);
    /// while it is up, it is typing during the wait between presses.
    private func otherKeyEventTrigger() -> KeyboardTrigger {
        if isFunctionKeyPressed {
            chordedPress = true
        }
        return .cancel
    }
    #endif

    private static let hotKeySignature = OSType(0x474C4245)
    private static let actionHotKeyID: UInt32 = 1

    /// NSSystemDefined has no CGEventType case in Swift; media and brightness
    /// keys arrive as these events.
    private static let systemDefinedEventType: UInt32 = 14
    /// The keycode macOS synthesizes as a keyDown/keyUp pair when the Globe
    /// key comes back up (kVK_NX_KeyType).
    private static let syntheticGlobeKeycode: Int64 = 179

    private func registerAppStoreHotKeys(target: EventTargetRef?) {
        register(
            appStoreShortcut,
            id: Self.actionHotKeyID,
            target: target,
            action: .press(.keyDown(Date()))
        )

        var nextID: UInt32 = 100
        for (sourceID, shortcut) in appStoreInputSourceShortcuts.sorted(by: { $0.key < $1.key }) {
            register(shortcut, id: nextID, target: target, action: .inputSource(id: sourceID))
            nextID += 1
        }
    }

    private func register(
        _ shortcut: CodableKeyboardShortcut,
        id: UInt32,
        target: EventTargetRef?,
        action: KeyboardTrigger
    ) {
        var registeredHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: id)
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            target,
            0,
            &registeredHotKeyRef
        )

        guard registerStatus == noErr, let registeredHotKeyRef else {
            DiagnosticLogger.log("KeyboardMonitor.start failed; RegisterEventHotKey shortcut=\(shortcut.displayName) status=\(registerStatus)")
            return
        }

        hotKeyRefs.append(registeredHotKeyRef)
        hotKeyActions[id] = action
        DiagnosticLogger.log("KeyboardMonitor registered shortcut \(shortcut.displayName) id=\(id)")
    }

    private func handleAppStoreHotKey(id: UInt32, eventKind: UInt32) {
        guard let action = hotKeyActions[id] else {
            return
        }

        if case let .inputSource(sourceID) = action {
            guard eventKind == UInt32(kEventHotKeyPressed) else {
                return
            }

            let handler = handler
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    handler(.inputSource(id: sourceID))
                }
            }
            return
        }

        let now = Date()
        let input: GlobePressInterpreter.Input
        if eventKind == UInt32(kEventHotKeyPressed) {
            input = .keyDown(now)
        } else if eventKind == UInt32(kEventHotKeyReleased) {
            input = .keyUp(now)
        } else {
            return
        }

        DiagnosticLogger.log("KeyboardMonitor interpreted app store action shortcut eventKind=\(eventKind)")
        let handler = handler

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(.press(input))
            }
        }
    }

    private func removeAppStoreEventHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }

        eventHandlerRef = nil
    }
}
