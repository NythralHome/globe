import Foundation

public struct GlobeSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var launchAtLogin: Bool
    public var showMenuBarIcon: Bool
    public var showSwitchingHUD: Bool
    public var hasCompletedOnboarding: Bool
    public var timing: GlobePressTiming
    public var mapping: CodableGlobeActionMapping

    public init(
        isEnabled: Bool = true,
        launchAtLogin: Bool = false,
        showMenuBarIcon: Bool = true,
        showSwitchingHUD: Bool = true,
        hasCompletedOnboarding: Bool = false,
        timing: GlobePressTiming = GlobePressTiming(),
        mapping: CodableGlobeActionMapping = CodableGlobeActionMapping()
    ) {
        self.isEnabled = isEnabled
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.showSwitchingHUD = showSwitchingHUD
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.timing = timing
        self.mapping = mapping
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
    }
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
