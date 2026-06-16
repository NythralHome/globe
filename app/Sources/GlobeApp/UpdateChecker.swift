import Foundation
import GlobeCore

struct ReleaseInfo: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [ReleaseAsset]
    let draft: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
        case draft
    }

    var installerAsset: ReleaseAsset? {
        assets
            .filter { $0.name.hasPrefix("Globe-") && $0.name.hasSuffix(".pkg") }
            .sorted { $0.name > $1.name }
            .first
    }
}

enum UpdateCheckResult {
    case upToDate(ReleaseInfo)
    case updateAvailable(ReleaseInfo)
}

struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
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

    static func downloadInstaller(from release: ReleaseInfo) async throws -> URL {
        guard let asset = release.installerAsset else {
            throw URLError(.fileDoesNotExist)
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: asset.browserDownloadURL)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let destinationURL = downloadsDirectory.appendingPathComponent(asset.name)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }
}
