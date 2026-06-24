/// The distribution channel this build was compiled for.
///
/// Policy: `#if GLOBE_APP_STORE` is reserved for code that must be *excluded* from
/// the sandboxed App Store binary (the global IOHID/Carbon key monitoring). Every
/// other channel difference — UI text, which update mechanism to use, which
/// permission to request — goes through the semantic properties below so intent is
/// readable at the call site and the compile-time branch lives in exactly one place.
enum AppDistribution {
    #if GLOBE_APP_STORE
    static let isAppStore = true
    #else
    static let isAppStore = false
    #endif

    /// The direct (Developer ID) build observes the physical Globe/Fn key globally
    /// via HID. The sandboxed App Store build cannot, and uses a Carbon hotkey.
    static var capturesGlobeKey: Bool { !isAppStore }

    /// Direct builds check for and install updates in-app; App Store builds defer
    /// to the App Store for updates.
    static var usesInAppUpdates: Bool { !isAppStore }

    /// Only the direct build needs Input Monitoring permission for HID capture.
    static var requiresInputMonitoring: Bool { !isAppStore }
}
