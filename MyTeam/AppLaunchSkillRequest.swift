import Foundation

struct AppLaunchSkillRequest: Codable, Equatable {
    let skillType: AppLaunchSkillType
    let appName: String
    let appCategory: String?
    let targetUser: String?
    let coreFeatures: [String]
    let monetizationModel: String?
    let tone: String?
    let notes: String?
}
