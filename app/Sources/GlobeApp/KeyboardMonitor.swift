import CoreGraphics
import Foundation
import GlobeCore

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
            return
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
            if monitor.handle(type: type, event: event) {
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .flagsChanged else {
            return false
        }

        let hasFunctionFlag = event.flags.contains(.maskSecondaryFn)
        guard hasFunctionFlag != isFunctionKeyPressed else {
            return false
        }

        isFunctionKeyPressed = hasFunctionFlag

        let now = Date()
        let input: GlobePressInterpreter.Input = hasFunctionFlag ? .keyDown(now) : .keyUp(now)
        let handler = handler

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(input)
            }
        }

        return true
    }
}
