import Foundation

enum DiagnosticLogger {
    static let logURL: URL = {
        let directory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Globe", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Globe.log")
    }()

    static func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logURL)
        }
    }

    static func recentLog(maxBytes: Int = 80_000) -> String {
        guard let data = try? Data(contentsOf: logURL) else {
            return "No diagnostic log exists yet."
        }

        let suffix = data.count > maxBytes ? data.suffix(maxBytes) : data[...]
        return String(decoding: suffix, as: UTF8.self)
    }
}
