import Foundation

public struct GlobeSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var launchAtLogin: Bool
    public var showMenuBarIcon: Bool
    public var showSwitchingHUD: Bool
    public var hasCompletedOnboarding: Bool
    public var timing: GlobePressTiming
    public var mapping: CodableGlobeActionMapping
    public var appStoreShortcut: CodableKeyboardShortcut
    public var appStoreInputSourceShortcuts: [String: CodableKeyboardShortcut]

    public init(
        isEnabled: Bool = true,
        launchAtLogin: Bool = false,
        showMenuBarIcon: Bool = true,
        showSwitchingHUD: Bool = true,
        hasCompletedOnboarding: Bool = false,
        timing: GlobePressTiming = GlobePressTiming(),
        mapping: CodableGlobeActionMapping = CodableGlobeActionMapping(),
        appStoreShortcut: CodableKeyboardShortcut = .controlOptionZ,
        appStoreInputSourceShortcuts: [String: CodableKeyboardShortcut] = [:]
    ) {
        self.isEnabled = isEnabled
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.showSwitchingHUD = showSwitchingHUD
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.timing = timing
        self.mapping = mapping
        self.appStoreShortcut = appStoreShortcut
        self.appStoreInputSourceShortcuts = appStoreInputSourceShortcuts
    }
}

extension GlobeSettings {
    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case launchAtLogin
        case showMenuBarIcon
        case showSwitchingHUD
        case hasCompletedOnboarding
        case timing
        case mapping
        case appStoreShortcut
        case appStoreInputSourceShortcuts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        showSwitchingHUD = try container.decodeIfPresent(Bool.self, forKey: .showSwitchingHUD) ?? true
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        timing = try container.decodeIfPresent(GlobePressTiming.self, forKey: .timing) ?? GlobePressTiming()
        mapping = try container.decodeIfPresent(CodableGlobeActionMapping.self, forKey: .mapping) ?? CodableGlobeActionMapping()
        appStoreShortcut = try container.decodeIfPresent(CodableKeyboardShortcut.self, forKey: .appStoreShortcut) ?? .controlOptionZ
        appStoreInputSourceShortcuts = try container.decodeIfPresent([String: CodableKeyboardShortcut].self, forKey: .appStoreInputSourceShortcuts) ?? [:]
    }
}

public struct CodableKeyboardShortcut: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayName: String

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let controlOptionZ = CodableKeyboardShortcut(
        keyCode: 6,
        modifiers: 6144,
        displayName: "Control-Option-Z"
    )

    public static let controlOptionG = CodableKeyboardShortcut(
        keyCode: 5,
        modifiers: 6144,
        displayName: "Control-Option-G"
    )

    public static let commandOptionG = CodableKeyboardShortcut(
        keyCode: 5,
        modifiers: 2304,
        displayName: "Command-Option-G"
    )

    public static let controlOptionSpace = CodableKeyboardShortcut(
        keyCode: 49,
        modifiers: 6144,
        displayName: "Control-Option-Space"
    )

    public static let commandOptionSpace = CodableKeyboardShortcut(
        keyCode: 49,
        modifiers: 2304,
        displayName: "Command-Option-Space"
    )

    public static let appStorePresets: [CodableKeyboardShortcut] = [
        .controlOptionZ,
        .controlOptionG,
        .commandOptionG,
        .controlOptionSpace,
        .commandOptionSpace
    ]
}

public enum CodableGlobePressAction: Codable, Equatable, Hashable, Sendable {
    case inputSource(id: String)
    case openSettings
    case showInputSourcePicker
    case none

    public var action: GlobePressAction {
        switch self {
        case let .inputSource(id):
            .inputSource(id: id)
        case .openSettings:
            .openSettings
        case .showInputSourcePicker:
            .showInputSourcePicker
        case .none:
            .none
        }
    }
}

public struct CodableGlobeActionMapping: Codable, Equatable, Sendable {
    public var singlePress: CodableGlobePressAction
    public var doublePress: CodableGlobePressAction
    public var triplePress: CodableGlobePressAction
    public var longPress: CodableGlobePressAction

    public init(
        singlePress: CodableGlobePressAction = .none,
        doublePress: CodableGlobePressAction = .none,
        triplePress: CodableGlobePressAction = .none,
        longPress: CodableGlobePressAction = .openSettings
    ) {
        self.singlePress = singlePress
        self.doublePress = doublePress
        self.triplePress = triplePress
        self.longPress = longPress
    }

    public var mapping: GlobeActionMapping {
        GlobeActionMapping(
            singlePress: singlePress.action,
            doublePress: doublePress.action,
            triplePress: triplePress.action,
            longPress: longPress.action
        )
    }
}

public protocol SettingsStoring {
    func load() -> GlobeSettings
    func save(_ settings: GlobeSettings)
}

public final class SettingsStore: SettingsStoring {
    private let userDefaults: UserDefaults
    private let key = "globe.settings"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> GlobeSettings {
        guard
            let data = userDefaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(GlobeSettings.self, from: data)
        else {
            return GlobeSettings()
        }

        return settings
    }

    public func save(_ settings: GlobeSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}
