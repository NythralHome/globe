import GlobeCore
import SwiftUI

@main
struct GlobeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = GlobeModel()

    var body: some Scene {
        MenuBarExtra("Globe", systemImage: "globe") {
            GlobeMenu(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}
