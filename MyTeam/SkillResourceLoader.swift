import Foundation

// MARK: - Decodable Models for skills.json

struct SkillsResource: Decodable {
    let version: String
    let lastUpdated: String
    let skills: [String: SkillData]
}

struct SkillData: Decodable {
    let intent: String
    let title: String
    let message: String
    let checklist: [String]
    let requiredInputs: [String]
    let nextActions: [String]
    let hardBlockedActions: [String]
    let keywords: Keywords

    enum CodingKeys: String, CodingKey {
        case intent, title, message, checklist
        case requiredInputs = "requiredInputs"
        case nextActions = "nextActions"
        case hardBlockedActions = "hardBlockedActions"
        case keywords
    }
}

struct Keywords: Decodable {
    let ko: [String]?
    let en: [String]?
    let ja: [String]?
}

// MARK: - Resource Loader

final class SkillResourceLoader {
    static let shared = SkillResourceLoader()

    private(set) var skills: [String: SkillData] = [:]
    private var isLoaded = false

    private init() {
        loadSkills()
    }

    func loadSkills() {
        guard let url = Bundle.main.url(forResource: "skills", withExtension: "json") else {
            AppLog.error("[SkillResourceLoader] skills.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let resource = try JSONDecoder().decode(SkillsResource.self, from: data)
            self.skills = resource.skills
            self.isLoaded = true
            AppLog.info("[SkillResourceLoader] Loaded \(resource.skills.count) skills from JSON")
        } catch {
            AppLog.error("[SkillResourceLoader] Failed to load skills.json: \(error)")
        }
    }

    func skill(for skillID: String) -> SkillData? {
        skills[skillID]
    }

    func allSkillIDs() -> [String] {
        Array(skills.keys)
    }

    func toKSkillAssistResponse(skillID: String) -> KSkillAssistResponse? {
        guard let data = skill(for: skillID) else { return nil }

        guard let intent = KSkillAssistIntent(rawValue: data.intent) else {
            return nil
        }

        return KSkillAssistResponse(
            intent: intent,
            title: data.title,
            message: data.message,
            checklist: data.checklist,
            nextActions: data.nextActions,
            hardBlockedActions: data.hardBlockedActions,
            requiredUserInputs: data.requiredInputs
        )
    }
}
