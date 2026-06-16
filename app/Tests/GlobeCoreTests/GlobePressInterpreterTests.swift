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
    func timeoutBeforeNextPressFinalizesPreviousPress() {
        let interpreter = GlobePressInterpreter(timing: timing)
        let start = Date(timeIntervalSince1970: 0)

        #expect(interpreter.handle(.keyDown(start)) == [])
        #expect(interpreter.handle(.keyUp(start.addingTimeInterval(0.04))) == [])
        #expect(interpreter.handle(.keyDown(start.addingTimeInterval(0.40))) == [.singlePress])
    }
}
