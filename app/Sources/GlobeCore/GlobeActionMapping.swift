import Foundation

public enum GlobePressAction: Equatable, Sendable {
    case inputSource(id: String)
    case openSettings
    case showInputSourcePicker
    case none
}

public struct GlobeActionMapping: Equatable, Sendable {
    public var singlePress: GlobePressAction
    public var doublePress: GlobePressAction
    public var triplePress: GlobePressAction
    public var longPress: GlobePressAction

    public init(
        singlePress: GlobePressAction = .none,
        doublePress: GlobePressAction = .none,
        triplePress: GlobePressAction = .none,
        longPress: GlobePressAction = .openSettings
    ) {
        self.singlePress = singlePress
        self.doublePress = doublePress
        self.triplePress = triplePress
        self.longPress = longPress
    }

    public func action(for interpretedAction: GlobePressInterpreter.Action) -> GlobePressAction {
        switch interpretedAction {
        case .singlePress:
            singlePress
        case .doublePress:
            doublePress
        case .triplePress:
            triplePress
        case .longPress:
            longPress
        }
    }
}
