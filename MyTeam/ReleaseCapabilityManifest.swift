import Foundation

enum ReleaseCapabilityStatus: String, Codable, Sendable {
    case pass = "PASS"
    case passBYOK = "PASS_BYOK"
    case disabled = "DISABLED"

    nonisolated var isApproved: Bool {
        switch self {
        case .pass, .passBYOK:
            return true
        case .disabled:
            return false
        }
    }
}

struct ReleaseCapabilityManifest: Codable, Sendable {
    struct Worker: Codable, Sendable {
        let contractVersion: Int
        let productionHealth: ReleaseCapabilityStatus
        let gitSHA: String?
        let deployedAt: String?

        enum CodingKeys: String, CodingKey {
            case contractVersion = "contract_version"
            case productionHealth = "production_health"
            case gitSHA = "git_sha"
            case deployedAt = "deployed_at"
        }
    }

    let schemaVersion: Int
    let testedCommit: String
    let profile: String
    let worker: Worker
    let providers: [String: ReleaseCapabilityStatus]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case testedCommit = "tested_commit"
        case profile
        case worker
        case providers
    }
}

enum ReleaseCapabilityManifestStore: Sendable {
    nonisolated static let generatedResourceName = "ReleaseCapabilityManifest.generated"
    nonisolated static let templateResourceName = "ReleaseCapabilityManifest.template"

    nonisolated static let bundled: ReleaseCapabilityManifest = {
        guard let url = Bundle.main.url(forResource: generatedResourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = parseManifest(data)
        else {
            return failClosedManifest
        }
        guard manifest.schemaVersion == 1 else {
            return failClosedManifest
        }
        return manifest
    }()

    nonisolated static var hasGeneratedManifest: Bool {
        Bundle.main.url(forResource: generatedResourceName, withExtension: "json") != nil
    }

    nonisolated static func status(for provider: String) -> ReleaseCapabilityStatus {
        bundled.providers[provider] ?? .disabled
    }

    private nonisolated static let failClosedManifest = ReleaseCapabilityManifest(
        schemaVersion: 1,
        testedCommit: "UNTESTED",
        profile: "releaseCandidate",
        worker: .init(
            contractVersion: 2,
            productionHealth: .disabled,
            gitSHA: nil,
            deployedAt: nil
        ),
        providers: [
            "google": .disabled,
            "finance": .disabled,
            "dart": .disabled,
            "kma": .disabled,
            "news": .disabled,
            "law": .disabled
        ]
    )

    private nonisolated static func parseManifest(_ data: Data) -> ReleaseCapabilityManifest? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schemaVersion = object["schema_version"] as? Int,
              let testedCommit = object["tested_commit"] as? String,
              let profile = object["profile"] as? String,
              let workerObject = object["worker"] as? [String: Any],
              let contractVersion = workerObject["contract_version"] as? Int,
              let productionHealthRaw = workerObject["production_health"] as? String,
              let productionHealth = ReleaseCapabilityStatus(rawValue: productionHealthRaw),
              let providersObject = object["providers"] as? [String: String]
        else {
            return nil
        }

        var providers: [String: ReleaseCapabilityStatus] = [:]
        for (key, rawStatus) in providersObject {
            guard let status = ReleaseCapabilityStatus(rawValue: rawStatus) else {
                return nil
            }
            providers[key] = status
        }

        return ReleaseCapabilityManifest(
            schemaVersion: schemaVersion,
            testedCommit: testedCommit,
            profile: profile,
            worker: .init(
                contractVersion: contractVersion,
                productionHealth: productionHealth,
                gitSHA: workerObject["git_sha"] as? String,
                deployedAt: workerObject["deployed_at"] as? String
            ),
            providers: providers
        )
    }
}
