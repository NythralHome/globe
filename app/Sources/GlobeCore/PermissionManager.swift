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
}
