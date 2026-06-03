import XCTest
@testable import MyTeam

final class CredentialSchemaTests: XCTestCase {
    func testNaverNewsRequiresClientIDAndClientSecret() {
        let schema = ExternalProvider.naverNews.credentialSchema

        XCTAssertEqual(schema.fields.map(\.id), ["clientID", "clientSecret"])
        XCTAssertEqual(schema.fields[0].label, "Client ID")
        XCTAssertEqual(schema.fields[1].label, "Client Secret")
        XCTAssertTrue(schema.fields[1].isSecret)
    }

    func testDARTAndKMAUseSingleNamedFields() {
        XCTAssertEqual(ExternalProvider.dartDisclosure.credentialSchema.fields.map(\.id), ["apiKey"])
        XCTAssertEqual(ExternalProvider.dartDisclosure.credentialSchema.fields[0].label, "API Key")
        XCTAssertEqual(ExternalProvider.kmaWeather.credentialSchema.fields.map(\.id), ["serviceKey"])
        XCTAssertEqual(ExternalProvider.kmaWeather.credentialSchema.fields[0].label, "Service Key")
    }

    func testKoreanLawUsesLawOCField() {
        let schema = ExternalProvider.koreanLaw.credentialSchema

        XCTAssertEqual(schema.fields.map(\.id), ["lawOC"])
        XCTAssertEqual(schema.fields[0].label, "LAW OC")
        XCTAssertTrue(schema.fields[0].isSecret)
    }

    func testPublicDataProvidersExposeDirectAndPlannedProxyModes() {
        XCTAssertEqual(ExternalProvider.naverNews.executionModes, [.byokDirect, .proxyPlanned])
        XCTAssertEqual(ExternalProvider.dartDisclosure.executionModes, [.byokDirect, .proxyPlanned])
        XCTAssertEqual(ExternalProvider.kmaWeather.executionModes, [.byokDirect, .proxyPlanned])
        XCTAssertEqual(ExternalProvider.koreanLaw.executionModes, [.byokDirect, .proxyPlanned])
    }

    func testAIProvidersOnlyExposeDirectMode() {
        XCTAssertEqual(ExternalProvider.openAI.executionModes, [.byokDirect])
        XCTAssertEqual(ExternalProvider.gemini.executionModes, [.byokDirect])
        XCTAssertEqual(ExternalProvider.anthropic.executionModes, [.byokDirect])
        XCTAssertEqual(ExternalProvider.openRouter.executionModes, [.byokDirect])
    }
}
