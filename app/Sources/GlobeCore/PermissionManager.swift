import Foundation
import IOKit.hid
import IOKit.hidsystem

public protocol PermissionManaging {
    var isInputMonitoringTrusted: Bool { get }
    @discardableResult
    func requestInputMonitoringPermission() -> Bool
}

public final class PermissionManager: PermissionManaging {
    public init() {}

    public var isInputMonitoringTrusted: Bool {
        #if GLOBE_APP_STORE
        true
        #else
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
            || Self.canOpenHIDManager()
        #endif
    }

    @discardableResult
    public func requestInputMonitoringPermission() -> Bool {
        #if GLOBE_APP_STORE
        true
        #else
        let hidTrusted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let hidManagerTrusted = Self.canOpenHIDManager()
        return hidTrusted || hidManagerTrusted
        #endif
    }

    private static func canOpenHIDManager() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, [
            hidMatchingDictionary(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Keyboard),
            hidMatchingDictionary(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Keypad)
        ] as CFArray)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return true
        }

        return false
    }

    private static func hidMatchingDictionary(usagePage: Int, usage: Int) -> CFDictionary {
        [
            kIOHIDDeviceUsagePageKey: usagePage,
            kIOHIDDeviceUsageKey: usage
        ] as CFDictionary
    }

}
