import Foundation

enum AgentRole: String, Codable, Equatable, CaseIterable {
    case researcher
    case drafter
    case reviewer
    case verifier
    case artifactWriter

    var displayName: String {
        switch self {
        case .researcher: return "자료 정리"
        case .drafter: return "초안 작성"
        case .reviewer: return "검토"
        case .verifier: return "검증"
        case .artifactWriter: return "저장"
        }
    }
}
