import Foundation

public struct GlobeVersion: Comparable, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let beta: Int?

    public init?(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)

        let parts = normalized.split(separator: "-", maxSplits: 1).map(String.init)
        let coreParts = parts[0].split(separator: ".").compactMap { Int($0) }
        guard coreParts.count == 3 else {
            return nil
        }

        major = coreParts[0]
        minor = coreParts[1]
        patch = coreParts[2]

        if parts.count == 2 {
            let prereleaseParts = parts[1].split(separator: ".").map(String.init)
            if prereleaseParts.count == 2, prereleaseParts[0] == "beta", let betaNumber = Int(prereleaseParts[1]) {
                beta = betaNumber
            } else {
                return nil
            }
        } else {
            beta = nil
        }
    }

    public static func < (lhs: GlobeVersion, rhs: GlobeVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        switch (lhs.beta, rhs.beta) {
        case let (.some(lhsBeta), .some(rhsBeta)):
            return lhsBeta < rhsBeta
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return false
        }
    }
}
