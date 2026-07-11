import Foundation

enum SkillPackageKind: String, Codable, CaseIterable, Sendable {
    case localSwift
    case directREST
    case myTeamProxy
    case externalMCP
    case disabled
}

enum SkillPackageExecutionMode: String, Codable, Sendable {
    case byokDirect
    case proxyPlanned
    case myTeamProxy
    case externalMCP
    case externalMCPLater
    case directRESTLater
    case disabled
}

struct SkillPackageRuntimePolicy: Codable, Equatable, Sendable {
    let autoLoad: Bool
    let userVisibleEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case autoLoad = "auto_load"
        case userVisibleEnabled = "user_visible_enabled"
    }
}

struct SkillPackageCredentialRequirement: Codable, Equatable, Sendable {
    enum RequirementType: String, Codable, Sendable {
        case provider
        case external
    }

    let type: RequirementType
    let provider: ExternalProvider?
    let fields: [String]
    let id: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case type, provider, fields, id, description
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RequirementType.self, forKey: .type)
        provider = try values.decodeIfPresent(ExternalProvider.self, forKey: .provider)
        fields = try values.decodeIfPresent([String].self, forKey: .fields) ?? []
        id = try values.decodeIfPresent(String.self, forKey: .id)
        description = try values.decodeIfPresent(String.self, forKey: .description)
    }
}

struct SkillPackageFailureMode: Codable, Equatable, Sendable {
    let code: String
    let message: String
}

struct SkillPackageSourcePolicy: Codable, Equatable, Sendable {
    let requiresSources: Bool
    let verifiedLabelRequires: String
    let requiresOfficialSource: Bool?
    let legalDisclaimerRequired: Bool?
    let requiredMetadata: [String]?
    let preferredSources: [String]?

    enum CodingKeys: String, CodingKey {
        case requiresSources = "requires_sources"
        case verifiedLabelRequires = "verified_label_requires"
        case requiresOfficialSource = "requires_official_source"
        case legalDisclaimerRequired = "legal_disclaimer_required"
        case requiredMetadata = "required_metadata"
        case preferredSources = "preferred_sources"
    }
}

struct SkillPackageUIContract: Codable, Equatable, Sendable {
    let card: String
    let requiresSourceLinks: Bool

    enum CodingKeys: String, CodingKey {
        case card
        case requiresSourceLinks = "requires_source_links"
    }
}

enum SkillPackageJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: SkillPackageJSONValue])
    case array([SkillPackageJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([SkillPackageJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: SkillPackageJSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct SkillPackageManifest: Codable, Equatable, Sendable {
    let id: String
    let version: String
    let kind: SkillPackageKind
    let displayName: String
    let description: String
    let sourceRepo: String
    let category: String?
    let runtime: SkillPackageRuntimePolicy
    let executionModes: [SkillPackageExecutionMode]
    let requiredCredentials: [SkillPackageCredentialRequirement]
    let inputSchema: SkillPackageJSONValue
    let outputSchema: SkillPackageJSONValue
    let failureModes: [SkillPackageFailureMode]
    let sourcePolicy: SkillPackageSourcePolicy
    let ui: SkillPackageUIContract
    let rules: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case version
        case kind
        case displayName = "display_name"
        case description
        case sourceRepo = "source_repo"
        case category
        case runtime
        case executionModes = "execution_modes"
        case requiredCredentials = "required_credentials"
        case inputSchema = "input_schema"
        case outputSchema = "output_schema"
        case failureModes = "failure_modes"
        case sourcePolicy = "source_policy"
        case ui
        case rules
    }
}

enum SkillPackageRegistry {
    static func decodePackage(_ data: Data, sourceURL: URL) throws -> SkillPackageManifest {
        try JSONDecoder().decode(SkillPackageManifest.self, from: data)
    }

    static func loadPackages(from rootURL: URL) throws -> [SkillPackageManifest] {
        let skillRoot = rootURL.appendingPathComponent("skills", isDirectory: true)
        let fileManager = FileManager.default
        guard let packageDirs = try? fileManager.contentsOfDirectory(
            at: skillRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try packageDirs.compactMap { directory in
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { return nil }
            let manifestURL = directory.appendingPathComponent("skill.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
            return try decodePackage(Data(contentsOf: manifestURL), sourceURL: manifestURL)
        }
    }

    static func validate(_ package: SkillPackageManifest) -> [String] {
        var errors: [String] = []

        if package.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("id is required")
        }
        if package.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("\(package.id): display_name is required")
        }
        if package.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("\(package.id): description is required")
        }
        if package.sourceRepo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("\(package.id): source_repo is required")
        }
        if package.failureModes.isEmpty {
            errors.append("\(package.id): failure_modes must not be empty")
        }
        if package.rules.isEmpty {
            errors.append("\(package.id): rules must not be empty")
        }
        if package.runtime.autoLoad || package.runtime.userVisibleEnabled {
            errors.append("\(package.id): reference packages must not be auto-loaded or user-visible yet")
        }
        if package.sourcePolicy.requiresSources && package.sourcePolicy.verifiedLabelRequires.isEmpty {
            errors.append("\(package.id): source_policy.verified_label_requires is required")
        }
        if isLegalPackage(package) {
            errors.append(contentsOf: validateLegalPackage(package))
        }

        for credential in package.requiredCredentials {
            switch credential.type {
            case .provider:
                errors.append(contentsOf: validateProviderCredential(credential, packageID: package.id))
            case .external:
                if credential.id?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    errors.append("\(package.id): external required_credentials requires id")
                }
            }
        }

        return errors
    }

    private static func validateProviderCredential(
        _ credential: SkillPackageCredentialRequirement,
        packageID: String
    ) -> [String] {
        guard let provider = credential.provider else {
            return ["\(packageID): provider required_credentials requires provider"]
        }
        let expected = Set(provider.credentialSchema.fields.map(\.id))
        let actual = Set(credential.fields)
        guard expected == actual else {
            return [
                "\(packageID): required_credentials for \(provider.rawValue) must match ProviderCredential schema fields \(expected.sorted())"
            ]
        }
        return []
    }

    private static func isLegalPackage(_ package: SkillPackageManifest) -> Bool {
        if package.id.hasPrefix("korean_law_") {
            return true
        }
        return package.category?.localizedCaseInsensitiveContains("legal") == true
    }

    private static func validateLegalPackage(_ package: SkillPackageManifest) -> [String] {
        var errors: [String] = []
        if package.sourcePolicy.requiresOfficialSource != true {
            errors.append("\(package.id): legal packages require source_policy.requires_official_source=true")
        }
        if package.sourcePolicy.legalDisclaimerRequired != true {
            errors.append("\(package.id): legal packages require source_policy.legal_disclaimer_required=true")
        }

        let failureCodes = Set(package.failureModes.map(\.code))
        if failureCodes.isDisjoint(with: ["citation_unverified", "citation_mismatch"]) {
            errors.append("\(package.id): legal packages require citation_unverified or citation_mismatch failure mode")
        }

        let requiredMetadata = Set(package.sourcePolicy.requiredMetadata ?? [])
        let expectedMetadata: Set<String> = [
            "law_name",
            "effective_date",
            "official_source_url",
            "verification_status"
        ]
        let missingMetadata = expectedMetadata.subtracting(requiredMetadata)
        if !missingMetadata.isEmpty {
            errors.append("\(package.id): legal packages require metadata \(missingMetadata.sorted())")
        }
        return errors
    }
}
