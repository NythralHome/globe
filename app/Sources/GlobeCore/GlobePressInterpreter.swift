import Foundation

public struct GlobePressTiming: Codable, Equatable, Sendable {
    public var multiPressTimeout: TimeInterval
    public var longPressDuration: TimeInterval

    public init(
        multiPressTimeout: TimeInterval = 0.30,
        longPressDuration: TimeInterval = 0.70
    ) {
        self.multiPressTimeout = multiPressTimeout
        self.longPressDuration = longPressDuration
    }
}

public final class GlobePressInterpreter {
    public enum Input: Equatable, Sendable {
        case keyDown(Date)
        case keyUp(Date)
        case timer(Date)
    }

    public enum Action: Equatable, Sendable {
        case singlePress
        case doublePress
        case triplePress
        case longPress
    }

    private let timing: GlobePressTiming
    private var keyDownDate: Date?
    private var pressCount = 0
    private var deadline: Date?

    public init(timing: GlobePressTiming = GlobePressTiming()) {
        self.timing = timing
    }

    @discardableResult
    public func handle(_ input: Input) -> [Action] {
        switch input {
        case let .keyDown(date):
            return handleKeyDown(at: date)
        case let .keyUp(date):
            return handleKeyUp(at: date)
        case let .timer(date):
            return handleTimer(at: date)
        }
    }

    public func reset() {
        keyDownDate = nil
        pressCount = 0
        deadline = nil
    }

    private func handleKeyDown(at date: Date) -> [Action] {
        guard keyDownDate == nil else {
            return []
        }

        if let deadline, date > deadline {
            let actions = finalizePendingPresses()
            keyDownDate = date
            return actions
        }

        keyDownDate = date
        return []
    }

    private func handleKeyUp(at date: Date) -> [Action] {
        guard let downDate = keyDownDate else {
            return []
        }

        keyDownDate = nil

        if date.timeIntervalSince(downDate) >= timing.longPressDuration {
            reset()
            return [.longPress]
        }

        pressCount += 1
        deadline = date.addingTimeInterval(timing.multiPressTimeout)

        if pressCount >= 3 {
            reset()
            return [.triplePress]
        }

        return []
    }

    private func handleTimer(at date: Date) -> [Action] {
        if let keyDownDate, date.timeIntervalSince(keyDownDate) >= timing.longPressDuration {
            reset()
            return [.longPress]
        }

        guard let deadline, date >= deadline else {
            return []
        }

        return finalizePendingPresses()
    }

    private func finalizePendingPresses() -> [Action] {
        let count = pressCount
        reset()

        switch count {
        case 1:
            return [.singlePress]
        case 2:
            return [.doublePress]
        case 3...:
            return [.triplePress]
        default:
            return []
        }
    }
}
