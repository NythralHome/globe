import Foundation
import Testing
@testable import GlobeCore

@Suite
struct GlobePressInterpreterTests {
    private let timing = GlobePressTiming(multiPressTimeout: 0.30, longPressDuration: 0.70)

    @Test
    func singlePressEmitsAfterTimeout() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.05))) == [])
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.34))) == [])
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.36))) == [.singlePress])
    }

    @Test
    func doublePressEmitsAfterTimeout() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.04))) == [])
        #expect(interpreter.handle(.keyDown(start.addingTimeInterval(0.12))) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.16))) == [])
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.47))) == [.doublePress])
    }

    @Test
    func triplePressEmitsImmediatelyOnThirdRelease() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.03))) == [])
        #expect(interpreter.handle(.keyDown(start.addingTimeInterval(0.10))) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.13))) == [])
        #expect(interpreter.handle(.keyDown(start.addingTimeInterval(0.20))) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.24))) == [.triplePress])
    }

    @Test
    func longPressEmitsOnRelease() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.71))) == [.longPress])
    }

    @Test
    func longPressEmitsOnTimerBeforeRelease() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.71))) == [.longPress])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.80))) == [])
    }

    @Test
    func timeoutBeforeNextPressFinalizesPreviousPress() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.04))) == [])
        #expect(interpreter.handle(.keyDown(start.addingTimeInterval(0.40))) == [.singlePress])
    }

    @Test
    func cancelDuringMultiPressWindowDropsPendingPress() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.04))) == [])
        #expect(interpreter.isPending)

        #expect(interpreter.handle(.cancel(start.addingTimeInterval(0.10))) == [])
        #expect(!interpreter.isPending)
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.36))) == [])
    }

    @Test
    func cancelBetweenPressesDropsTheCount() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.04))) == [])
        #expect(interpreter.handle(.cancel(start.addingTimeInterval(0.06))) == [])
        #expect(interpreter.handle(.keyDown(start.addingTimeInterval(0.12))) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.16))) == [])
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.47))) == [.singlePress])
    }

    @Test
    func cancelWhileKeyDownPreventsReleaseFromCounting() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.cancel(start.addingTimeInterval(0.10))) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.14))) == [])
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.50))) == [])
    }

    @Test
    func cancelDuringChordedLongPressPreventsLongPress() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.cancel(start.addingTimeInterval(0.10))) == [])
        #expect(interpreter.handle(.timer(start.addingTimeInterval(0.71))) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.80))) == [])
    }

    @Test
    func cancelWhileIdleIsANoOp() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.cancel(start)) == [])
        #expect(!interpreter.isPending)
    }
}
