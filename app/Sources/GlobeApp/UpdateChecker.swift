import Foundation

struct ReleaseInfo: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let draft: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case draft
    }
}

enum UpdateCheckResult {
    case upToDate(ReleaseInfo)
    case updateAvailable(ReleaseInfo)
}

enum UpdateChecker {
    static func check() async throws -> UpdateCheckResult {
        var request = URLRequest(url: AppLinks.releasesAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let releases = try JSONDecoder().decode([ReleaseInfo].self, from: data)
        guard let latestRelease = releases.first(where: { !$0.draft }) else {
            throw URLError(.resourceUnavailable)
        }

        if normalized(latestRelease.tagName) == normalized(AppVersion.versionString) {
            return .upToDate(latestRelease)
        }

        return .updateAvailable(latestRelease)
    }

    private static func normalized(_ version: String) -> String {
        version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
    }
}
