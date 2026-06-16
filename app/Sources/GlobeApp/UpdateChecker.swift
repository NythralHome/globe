import Foundation
import GlobeCore

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
        guard let latestRelease = releases
            .filter({ !$0.draft })
            .compactMap({ release -> (ReleaseInfo, GlobeVersion)? in
                guard let version = GlobeVersion(release.tagName) else {
                    return nil
                }
                return (release, version)
            })
            .max(by: { $0.1 < $1.1 })
        else {
            throw URLError(.resourceUnavailable)
        }

        guard let installedVersion = GlobeVersion(AppVersion.versionString) else {
            return .upToDate(latestRelease.0)
        }

        if latestRelease.1 > installedVersion {
            return .updateAvailable(latestRelease.0)
        }

        return .upToDate(latestRelease.0)
    }
}
