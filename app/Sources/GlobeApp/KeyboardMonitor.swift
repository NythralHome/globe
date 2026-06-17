import CoreGraphics
import Foundation
import GlobeCore
import Carbon.HIToolbox

final class KeyboardMonitor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFunctionKeyPressed = false
    private let handler: @MainActor (GlobePressInterpreter.Input) -> Void

    init(handler: @escaping @MainActor (GlobePressInterpreter.Input) -> Void) {
        self.handler = handler
    }

    func start() {
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
    }

    func stop() {
        DiagnosticLogger.log("KeyboardMonitor.stop")
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
    }

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
                handler(input)
            }
        }

        return true
    }
}
