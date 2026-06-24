import AppKit
import CoreGraphics
import Foundation
import GlobeCore

#if !GLOBE_APP_STORE
enum TextLayoutFixResult {
    case fixed(String)
    case noSelection
    case failed(String)
}

@MainActor
final class TextLayoutFixer {
    private let pasteboard = NSPasteboard.general

    func fixSelectedText(
        targetSource: InputSource,
        completion: @escaping @MainActor (TextLayoutFixResult) -> Void
    ) {
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let originalChangeCount = pasteboard.changeCount

        postCommandKey(keyCode: 8)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self else { return }

            guard pasteboard.changeCount != originalChangeCount else {
                completion(.noSelection)
                return
            }

            guard let selectedText = pasteboard.string(forType: .string), !selectedText.isEmpty else {
                snapshot.restore(to: pasteboard)
                completion(.noSelection)
                return
            }

            guard let fixedText = KeyboardLayoutConverter.convert(selectedText, targetSource: targetSource),
                  fixedText != selectedText
            else {
                snapshot.restore(to: pasteboard)
                completion(.noSelection)
                return
            }

            pasteboard.clearContents()
            pasteboard.setString(fixedText, forType: .string)
            let replacementChangeCount = pasteboard.changeCount

            postCommandKey(keyCode: 9)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                if self.pasteboard.changeCount == replacementChangeCount {
                    snapshot.restore(to: self.pasteboard)
                }

                completion(.fixed(fixedText))
            }
        }
    }

    private func postCommandKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let flags: CGEventFlags = .maskCommand

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let capturedItems: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            Dictionary<NSPasteboard.PasteboardType, Data>(uniqueKeysWithValues: item.types.compactMap { type in
                guard let data = item.data(forType: type) else {
                    return nil
                }

                return (type, data)
            })
        } ?? []

        return PasteboardSnapshot(items: capturedItems)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let pasteboardItems = items.map { itemData in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(pasteboardItems)
    }
}

private enum KeyboardLayoutConverter {
    private static let latin = "`qwertyuiop[]asdfghjkl;'zxcvbnm,./~QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?"
    private static let ukrainian = "'йцукенгшщзхїфівапролджєячсмитьбю.₴ЙЦУКЕНГШЩЗХЇФІВАПРОЛДЖЄЯЧСМИТЬБЮ,"
    private static let russian = "ёйцукенгшщзхъфывапролджэячсмитьбю.ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"

    static func convert(_ text: String, targetSource: InputSource) -> String? {
        let target = "\(targetSource.id) \(targetSource.localizedName)".lowercased()

        if target.contains("ukrainian") || target.contains("укра") || target.contains(".ukrainian") {
            return translate(text, from: latin, to: ukrainian)
        }

        if target.contains("russian") || target.contains("рус") || target.contains(".russian") {
            return translate(text, from: latin, to: russian)
        }

        if target.contains("abc") || target.contains("u.s.") || target.contains("us") || target.contains("english") {
            let fromUkrainian = translate(text, from: ukrainian, to: latin)
            let fromRussian = translate(text, from: russian, to: latin)
            return score(fromUkrainian) >= score(fromRussian) ? fromUkrainian : fromRussian
        }

        return nil
    }

    private static func translate(_ text: String, from source: String, to target: String) -> String {
        let sourceCharacters = Array(source)
        let targetCharacters = Array(target)
        let pairs = zip(sourceCharacters, targetCharacters)
        let table = Dictionary(uniqueKeysWithValues: pairs)

        return String(text.map { table[$0] ?? $0 })
    }

    private static func score(_ text: String) -> Int {
        text.reduce(0) { score, character in
            if character.isASCII {
                score + 1
            } else {
                score
            }
        }
    }
}
#endif
