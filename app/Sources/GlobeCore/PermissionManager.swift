import CoreGraphics
import Foundation

public protocol PermissionManaging {
    var isAccessibilityTrusted: Bool { get }
    @discardableResult
    func requestAccessibilityPermission() -> Bool
}

public final class PermissionManager: PermissionManaging {
    public init() {}

    public var isAccessibilityTrusted: Bool {
        #if GLOBE_APP_STORE
        true
        #else
        CGPreflightListenEventAccess()
        #endif
    }

    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        #if GLOBE_APP_STORE
        true
        #else
        CGRequestListenEventAccess()
        #endif
    }

    private static func probeListenOnlyEventTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, _, event, _ in
            Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) else {
            return false
        }

        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }
}
