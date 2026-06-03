import XCTest
@testable import MyTeam

final class SkillPackageRegistryTests: XCTestCase {
    func testRegistryAcceptsReferencePackageMetadataWithoutEnablingRuntimeUse() throws {
        let package = try SkillPackageRegistry.decodePackage(
            Data(Self.referenceSkillJSON.utf8),
            sourceURL: URL(fileURLWithPath: "/tmp/skills/naver_news_search/skill.json")
        )

        let errors = SkillPackageRegistry.validate(package)

        XCTAssertEqual(errors, [])
        XCTAssertEqual(package.id, "naver_news_search")
        XCTAssertEqual(package.requiredCredentials.first?.provider, .naverNews)
        XCTAssertEqual(package.requiredCredentials.first?.fields, ["clientID", "clientSecret"])
        XCTAssertFalse(package.runtime.autoLoad)
        XCTAssertFalse(package.runtime.userVisibleEnabled)
    }

    func testRegistryRejectsCredentialFieldsThatDoNotMatchProviderSchema() throws {
        let invalidJSON = Self.referenceSkillJSON.replacingOccurrences(
            of: #""clientSecret""#,
            with: #""apiKey""#
        )
        let package = try SkillPackageRegistry.decodePackage(
            Data(invalidJSON.utf8),
            sourceURL: URL(fileURLWithPath: "/tmp/skills/naver_news_search/skill.json")
        )

        let errors = SkillPackageRegistry.validate(package)

        XCTAssertTrue(errors.contains { $0.contains("required_credentials") && $0.contains("naverNews") })
    }

    private static let referenceSkillJSON = """
    {
      "id": "naver_news_search",
      "display_name": "Naver News Search",
      "version": "0.1.0",
      "kind": "directREST",
      "category": "koreanBusiness",
      "description": "Reference package for searching Naver News with BYOK credentials.",
      "source_repo": "https://github.com/NomaDamas/k-skill",
      "runtime": {
        "auto_load": false,
        "user_visible_enabled": false
      },
      "required_credentials": [
        {
          "type": "provider",
          "provider": "naverNews",
          "fields": ["clientID", "clientSecret"]
        }
      ],
      "execution_modes": ["byokDirect", "proxyPlanned"],
      "input_schema": {
        "type": "object",
        "required": ["query"],
        "properties": {
          "query": { "type": "string" }
        }
      },
      "output_schema": {
        "type": "object",
        "required": ["items", "sources"],
        "properties": {
          "items": { "type": "array" },
          "sources": { "type": "array" }
        }
      },
      "failure_modes": [
        { "code": "missing_credentials", "message": "Naver Client ID and Client Secret are required." }
      ],
      "source_policy": {
        "requires_sources": true,
        "verified_label_requires": "provider_response_with_source_url"
      },
      "ui": {
        "card": "news_search_results",
        "requires_source_links": true
      },
      "rules": [
        "Do not summarize news without source links.",
        "Query must be at least two characters.",
        "Clean HTML tags from titles and descriptions."
      ],
      "artifact_policy": {
        "default_artifact": "none"
      },
      "manual_live_tests": {
        "requires_valid_credentials": true,
        "cases_file": "tests/validator_cases.json"
      }
    }
    """
}
