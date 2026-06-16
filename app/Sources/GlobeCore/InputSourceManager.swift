import Carbon
import Foundation

public struct InputSource: Identifiable, Hashable, Sendable {
    public let id: String
    public let localizedName: String

    public init(id: String, localizedName: String) {
        self.id = id
        self.localizedName = localizedName
    }
}

public protocol InputSourceManaging {
    func availableInputSources() -> [InputSource]
    func currentInputSource() -> InputSource?
    func selectInputSource(id: String) throws
}

public enum InputSourceError: Error, Equatable {
    case sourceNotFound(String)
    case selectionFailed(String)
}

public final class InputSourceManager: InputSourceManaging {
    public init() {}

    public func availableInputSources() -> [InputSource] {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource
        ] as CFDictionary

        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        return list.compactMap(Self.makeInputSource)
    }

    public func currentInputSource() -> InputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        return Self.makeInputSource(source)
    }

    public func selectInputSource(id: String) throws {
        let filter = [
            kTISPropertyInputSourceID as String: id
        ] as CFDictionary

        guard
            let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
            let source = list.first
        else {
            throw InputSourceError.sourceNotFound(id)
        }

        let status = TISSelectInputSource(source)
        guard status == noErr else {
            throw InputSourceError.selectionFailed(id)
        }
    }

    private static func makeInputSource(_ source: TISInputSource) -> InputSource? {
        guard let id = stringProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }

        let name = stringProperty(source, kTISPropertyLocalizedName) ?? id
        return InputSource(id: id, localizedName: name)
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let rawValue = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        return Unmanaged<CFString>.fromOpaque(rawValue).takeUnretainedValue() as String
    }
}
