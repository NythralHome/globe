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
        CGPreflightListenEventAccess()
    }

    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        CGRequestListenEventAccess()
    }
}
