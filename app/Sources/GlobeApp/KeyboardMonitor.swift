import AppKit
import Foundation
import GlobeCore
import Carbon.HIToolbox
#if !GLOBE_APP_STORE
import IOKit.hid
#endif

enum KeyboardTrigger: Sendable {
    case press(GlobePressInterpreter.Input)
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
    private var hidManager: IOHIDManager?
    // The IOHIDManager callback holds a raw pointer back to this object. Retain
    // self for the lifetime of the registration so the callback can never fire
    // against freed memory; balanced by release() in stopHIDMonitor.
    private var hidRetainedSelf: Unmanaged<KeyboardMonitor>?
    #endif
    private var isFunctionKeyPressed = false
    private let handler: @MainActor (KeyboardTrigger) -> Void

    init(handler: @escaping @MainActor (KeyboardTrigger) -> Void) {
        self.handler = handler
    }

    deinit {
        // The HID callback and Carbon hotkeys hold an unretained pointer back to
        // this object via the main run loop. If the monitor is deallocated without
        // unregistering them (e.g. a discarded GlobeModel instance), the next key
        // event dereferences freed memory and crashes. Tear everything down here.
        stop()
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
            startHIDMonitor()
        } else {
            DiagnosticLogger.log("KeyboardMonitor.start skipped HID monitor; Input Monitoring is missing")
            stopHIDMonitor()
        }
        #endif
    }

    func stop() {
        DiagnosticLogger.log("KeyboardMonitor.stop")
        stopHotKeys()
        #if !GLOBE_APP_STORE
        stopHIDMonitor()
        #endif
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
    private func startHIDMonitor() {
        guard hidManager == nil else {
            DiagnosticLogger.log("KeyboardMonitor.start ignored; HID monitor already exists")
            return
        }

        DiagnosticLogger.log("KeyboardMonitor.start HID monitor")
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, [
            Self.hidMatchingDictionary(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Keyboard),
            Self.hidMatchingDictionary(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Keypad)
        ] as CFArray)

        // IOHIDValueCallback parameters are (context, result, sender, value). The
        // context is the refcon we registered below; the third parameter is the
        // sending device, NOT our object. Reading the wrong parameter would
        // reconstruct a KeyboardMonitor from a device pointer and crash.
        let callback: IOHIDValueCallback = { context, _, _, value in
            guard let context else {
                return
            }

            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handleHIDValue(value)
        }
        // Retain self for the lifetime of the registration so the callback can
        // never fire against freed memory; balanced by release() in stopHIDMonitor.
        let retainedSelf = Unmanaged.passRetained(self)
        hidRetainedSelf = retainedSelf
        IOHIDManagerRegisterInputValueCallback(manager, callback, retainedSelf.toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
            hidRetainedSelf?.release()
            hidRetainedSelf = nil
            DiagnosticLogger.log("KeyboardMonitor.start failed; IOHIDManagerOpen result=\(openResult)")
            return
        }

        hidManager = manager
        DiagnosticLogger.log("KeyboardMonitor.start created HID monitor")
    }

    private func stopHIDMonitor() {
        guard let hidManager else {
            return
        }

        IOHIDManagerRegisterInputValueCallback(hidManager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidManager = nil
        hidRetainedSelf?.release()
        hidRetainedSelf = nil
    }

    private func handleHIDValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        guard usagePage == 0xff, usage == 0x3 else {
            return
        }

        let isPressed = IOHIDValueGetIntegerValue(value) != 0
        guard isPressed != isFunctionKeyPressed else {
            return
        }

        isFunctionKeyPressed = isPressed

        let input: GlobePressInterpreter.Input = isPressed ? .keyDown(Date()) : .keyUp(Date())
        DiagnosticLogger.log("KeyboardMonitor interpreted HID Fn \(isPressed ? "keyDown" : "keyUp")")
        let handler = handler

        Task { @MainActor in
            handler(.press(input))
        }
    }

    private static func hidMatchingDictionary(usagePage: Int, usage: Int) -> CFDictionary {
        [
            kIOHIDDeviceUsagePageKey: usagePage,
            kIOHIDDeviceUsageKey: usage
        ] as CFDictionary
    }
    #endif

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
