import Foundation

struct UniversalDocumentSkillRequest: Equatable {
    let type: UniversalDocumentSkillType
    let title: String
    let topic: String
    let sourceText: String?
    let userMessage: String
}
