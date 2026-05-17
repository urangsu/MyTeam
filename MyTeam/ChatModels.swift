import Foundation

// MARK: - Chat Data Models (AgentWindowManager에서 분리)
// AgentWindowManager.ChatRoom / AgentWindowManager.ChatLog 타입 유지

extension AgentWindowManager {

    // ── 채팅방(워크룸/개인 대화) 모델 ──
    struct ChatRoom: Identifiable, Codable {
        let id: UUID
        var name: String
        var messages: [ChatLog]
        var agentIDs: [String]
        var leaderAgentID: String? = nil
        var profile: RoomProfile? = nil
        let createdAt: Date

        /// Round 146A: agentIDs 기반 방 종류 자동 판정
        var computedRoomKind: RoomKind {
            if agentIDs.contains("team_all") || agentIDs.count > 1 {
                return .teamWorkroom
            }
            return .personalChat
        }

        var effectiveProfile: RoomProfile {
            profile ?? .general()
        }
    }

    // ── 채팅 메시지 모델 ──
    struct ChatLog: Identifiable, Codable {
        let id: UUID
        let agentID: String
        let agentName: String
        let text: String
        let isUser: Bool
        let timestamp: Date
        var isSystem: Bool = false  // 드래그/이벤트 등 시스템 대사 (채팅창에 표시 안 함)
        var attachments: [ChatAttachment] = []  // 첨부파일
        var sources: [SourceReference] = []  // 웹 검색/자료 출처
        var skillID: String? = nil
        var artifactIDs: [String] = []  // Round 146A: 이 메시지가 생성한 artifact ID 목록
    }

    // ── 워크룸/개인 대화 구분 (Round 146A) ──
    enum RoomKind: String, Codable {
        case teamWorkroom    // 팀 전체 협업 공간 (team_all 또는 agentIDs 2개+)
        case personalChat    // 개인 에이전트 대화 (agentIDs 1개)
    }

    enum RoomMode: String, Codable, Sendable {
        case general
        case blogWriting

        var displayName: String {
            switch self {
            case .general:
                return "일반 워크룸"
            case .blogWriting:
                return "콘텐츠 초안 보조"
            }
        }
    }

    struct RoomProfile: Codable, Equatable, Sendable {
        var mode: RoomMode
        var purpose: String
        var systemInstruction: String
        var sourceURLs: [String]
        var styleProfile: BlogStyleProfile?
        var seoProfile: BlogSEOProfile?
        var preferredOutputFormat: String?

        static func general() -> RoomProfile {
            RoomProfile(
                mode: .general,
                purpose: "",
                systemInstruction: "",
                sourceURLs: [],
                styleProfile: nil,
                seoProfile: nil,
                preferredOutputFormat: nil
            )
        }

        static func blogWriting(sourceURLs: [String] = []) -> RoomProfile {
            RoomProfile(
                mode: .blogWriting,
                purpose: "콘텐츠 초안 보조",
                systemInstruction: """
                이 워크룸은 MyTeam의 문서/파일/표/정리 핵심 루프 안에서 콘텐츠 초안을 보조한다. 사용자가 상황, 키워드, 참고 URL, 기존 글을 주면 제목 후보, 검색 의도, 본문 초안, 메타 설명, FAQ, 태그, 발행 전 체크리스트를 함께 제안한다. 기존 글투가 제공되면 과장하지 말고 문장 리듬, 표현 습관, CTA 패턴을 참고하되, 결과물은 사용자가 바로 고쳐 쓸 수 있는 업무 초안으로 만든다.
                """,
                sourceURLs: sourceURLs,
                styleProfile: .empty,
                seoProfile: .defaultKoreanBlog,
                preferredOutputFormat: "제목 후보 → 추천 제목 → 초안 개요 → 본문 초안 → 메타 설명/태그/FAQ → 개선 체크리스트"
            )
        }
    }

    struct BlogStyleProfile: Codable, Equatable, Sendable {
        var voiceSummary: String
        var headlinePatterns: [String]
        var introPatterns: [String]
        var expressionNotes: [String]
        var ctaPatterns: [String]
        var bannedPhrases: [String]

        static let empty = BlogStyleProfile(
            voiceSummary: "아직 분석된 기존 글투가 없습니다. 사용자가 공개 글 URL을 제공하면 스타일 특징을 이 워크룸 참고 정보로 축적하세요.",
            headlinePatterns: [],
            introPatterns: [],
            expressionNotes: [],
            ctaPatterns: [],
            bannedPhrases: []
        )
    }

    struct BlogSEOProfile: Codable, Equatable, Sendable {
        var targetLocale: String
        var requiredSections: [String]
        var checklist: [String]

        static let defaultKoreanBlog = BlogSEOProfile(
            targetLocale: "ko-KR",
            requiredSections: ["검색 의도", "핵심 키워드", "H1/H2 구조", "메타 설명", "FAQ", "태그", "내부링크 제안"],
            checklist: [
                "주 키워드를 제목/H1/첫 문단에 자연스럽게 포함",
                "검색자가 바로 얻고 싶은 답을 첫 300자 안에 제시",
                "소제목은 질문형/문제 해결형을 섞어서 작성",
                "중복 표현과 과장된 광고 문구를 줄이고 구체 사례를 사용",
                "발행 전 메타 설명 80-150자, slug, 태그, FAQ를 확인"
            ]
        )
    }

    struct SourceReference: Identifiable, Codable, Hashable {
        var id: UUID = UUID()
        let title: String
        let url: String
        let provider: String
        let accessedAt: Date
    }

    struct AutomationTask: Identifiable, Codable, Hashable {
        let id: UUID
        var title: String
        var prompt: String
        var nextRunAt: Date
        var repeatInterval: TimeInterval?
        var roomID: UUID?
        var assignedAgentID: String?
        var isEnabled: Bool
        var createdAt: Date
        var lastRunAt: Date?
        /// true면 실행 전 채팅창에 승인 요청. 2분 내 /approve {id} 없으면 자동 실행.
        var requiresApproval: Bool = false

        var scheduleText: String {
            if let repeatInterval {
                if repeatInterval >= 3600 {
                    return "매 \(Int(repeatInterval / 3600))시간"
                }
                return "매 \(max(1, Int(repeatInterval / 60)))분"
            }
            return nextRunAt.formatted(date: .omitted, time: .shortened)
        }
    }

}
