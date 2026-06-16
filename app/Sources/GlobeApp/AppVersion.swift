import Foundation

enum AppVersion {
    static var versionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    static var displayString: String {
        let version = versionString
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch build {
        case let .some(build):
            return "\(version) (\(build))"
        case .none:
            return version
        }
    }
}
