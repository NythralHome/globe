import ApplicationServices
import Foundation

public protocol PermissionManaging {
    var isAccessibilityTrusted: Bool { get }
    func requestAccessibilityPermission()
}

public final class PermissionManager: PermissionManaging {
    public init() {}

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        AXIsProcessTrustedWithOptions(options)
    }
}
