import AppKit
import CoreGraphics
import Foundation
import GlobeCore
import Carbon.HIToolbox

enum KeyboardTrigger: Sendable {
    case press(GlobePressInterpreter.Input)
    case inputSource(id: String)
}

final class KeyboardMonitor: @unchecked Sendable {
    #if GLOBE_APP_STORE
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var appStoreShortcut: CodableKeyboardShortcut = .controlOptionZ
    private var appStoreInputSourceShortcuts: [String: CodableKeyboardShortcut] = [:]
    private var hotKeyActions: [UInt32: KeyboardTrigger] = [:]
    #else
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    #endif
    private var isFunctionKeyPressed = false
    private let handler: @MainActor (KeyboardTrigger) -> Void

    init(handler: @escaping @MainActor (KeyboardTrigger) -> Void) {
        self.handler = handler
    }

    #if GLOBE_APP_STORE
    func configureAppStoreShortcuts(
        actionShortcut: CodableKeyboardShortcut,
        inputSourceShortcuts: [String: CodableKeyboardShortcut]
    ) {
        appStoreShortcut = actionShortcut
        appStoreInputSourceShortcuts = inputSourceShortcuts
    }
    #endif

    func start() {
        #if GLOBE_APP_STORE
        guard hotKeyRefs.isEmpty else {
            DiagnosticLogger.log("KeyboardMonitor.start ignored; app store hotkey already exists")
            return
        }

        DiagnosticLogger.log("KeyboardMonitor.start app store hotkeys")
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
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
                monitor.handleAppStoreHotKey(id: hotKeyID.id)
                return noErr
            },
            1,
            &eventType,
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
        #else
        guard eventTap == nil else {
            DiagnosticLogger.log("KeyboardMonitor.start ignored; event tap already exists")
            return
        }

        DiagnosticLogger.log("KeyboardMonitor.start")
        let mask = (1 << CGEventType.flagsChanged.rawValue)
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
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        DiagnosticLogger.log("KeyboardMonitor.start created HID event tap")
        #endif
    }

    func stop() {
        DiagnosticLogger.log("KeyboardMonitor.stop")
        #if GLOBE_APP_STORE
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefs = []
        hotKeyActions = [:]
        removeAppStoreEventHandler()
        #else
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
        #endif
    }

    #if !GLOBE_APP_STORE
    private func enableEventTap() {
        guard let eventTap else {
            return
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        DiagnosticLogger.log("KeyboardMonitor re-enabled event tap")
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .flagsChanged else {
            return false
        }

        let hasFunctionFlag = event.flags.contains(.maskSecondaryFn)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        DiagnosticLogger.log("flagsChanged keyCode=\(keyCode) flags=\(event.flags.rawValue) hasFunctionFlag=\(hasFunctionFlag)")

        guard hasFunctionFlag != isFunctionKeyPressed else {
            return false
        }

        isFunctionKeyPressed = hasFunctionFlag

        let now = Date()
        let input: GlobePressInterpreter.Input = hasFunctionFlag ? .keyDown(now) : .keyUp(now)
        DiagnosticLogger.log("KeyboardMonitor interpreted \(hasFunctionFlag ? "keyDown" : "keyUp")")
        let handler = handler

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(.press(input))
            }
        }

        return true
    }
    #endif

    #if GLOBE_APP_STORE
    private static let hotKeySignature = OSType(0x474C4245)
    private static let actionHotKeyID: UInt32 = 1

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

    private func handleAppStoreHotKey(id: UInt32) {
        guard let action = hotKeyActions[id] else {
            return
        }

        if case let .inputSource(sourceID) = action {
            let handler = handler
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    handler(.inputSource(id: sourceID))
                }
            }
            return
        }

        let now = Date()
        DiagnosticLogger.log("KeyboardMonitor interpreted app store action shortcut")
        let handler = handler

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(.press(.keyDown(now)))
                handler(.press(.keyUp(Date())))
            }
        }
    }

    private func removeAppStoreEventHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }

        eventHandlerRef = nil
    }
    #endif
}
