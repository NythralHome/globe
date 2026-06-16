import Testing
@testable import GlobeCore

@Suite
struct GlobeVersionTests {
    @Test
    func comparesBetaVersionsNumerically() throws {
        let beta6 = try #require(GlobeVersion("v0.1.0-beta.6"))
        let beta7 = try #require(GlobeVersion("0.1.0-beta.7"))

        #expect(beta7 > beta6)
    }

    @Test
    func releaseVersionIsNewerThanBeta() throws {
        let beta = try #require(GlobeVersion("0.1.0-beta.8"))
        let release = try #require(GlobeVersion("0.1.0"))

        #expect(release > beta)
    }
}
