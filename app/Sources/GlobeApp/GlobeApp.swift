import GlobeCore
import SwiftUI

@main
struct GlobeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // SwiftUI may evaluate this initializer expression more than once while it
    // re-creates the App value. GlobeModel.init starts the global HID monitor as
    // a side effect, so a throwaway instance would leave an IOHIDManager firing
    // against freed memory. Route through a single shared instance so exactly one
    // GlobeModel (and one KeyboardMonitor) ever exists.
    @StateObject private var model = GlobeModel.shared

    var body: some Scene {
        MenuBarExtra("Globe", systemImage: "globe") {
            GlobeMenu(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}
