import Testing
@testable import GlobeCore

@Suite
struct GlobeActionMappingTests {
    @Test
    func mapsInterpretedActionsToConfiguredActions() {
        let mapping = GlobeActionMapping(
            singlePress: .inputSource(id: "ua"),
            doublePress: .inputSource(id: "en"),
            triplePress: .inputSource(id: "pl"),
            longPress: .openSettings
        )

        #expect(mapping.action(for: .singlePress) == .inputSource(id: "ua"))
        #expect(mapping.action(for: .doublePress) == .inputSource(id: "en"))
        #expect(mapping.action(for: .triplePress) == .inputSource(id: "pl"))
        #expect(mapping.action(for: .longPress) == .openSettings)
    }
}
