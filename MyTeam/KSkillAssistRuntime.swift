import Foundation

// Round 249A-KSKILLS-ASSIST: Lifestyle & public-read assist runtime
// Policy: No fake API calls, no auto booking/payment/login
// All skills return checklist + required inputs + blocked actions

// MARK: - Intent

enum KSkillAssistIntent: String, Codable, Sendable {
    case transportationBookingAssist  // 기차/버스/항공 예매
    case accommodationAssist          // 숙박 예약 준비
    case investmentResearchAssist     // 주가/투자 정보 조회
    case newsResearchAssist           // 뉴스 리서치
    case travelPlanningAssist         // 여행 준비
    case businessDocumentAssist       // 사무 문서 검토
    case fileProcessingAssist         // 파일/이미지 처리
}

// MARK: - Response

struct KSkillAssistResponse: Sendable {
    let intent: KSkillAssistIntent
    let title: String
    let message: String
    let checklist: [String]
    let nextActions: [String]
    let hardBlockedActions: [String]
    let requiredUserInputs: [String]
}

// MARK: - Parsed Sections

struct KSkillAssistParsedSections: Sendable {
    let title: String
    let message: String
    let checklist: [String]
    let requiredInputs: [String]
    let nextActions: [String]
    let hardBlockedActions: [String]
}

// MARK: - Runtime

enum KSkillAssistRuntime {

    // MARK: - Skill ID Registry

    private static let assistSkillIDs: Set<String> = [
        "transportation-booking",
        "accommodation-planning",
        "investment-research",
        "news-research",
        "travel-planning",
        "business-document",
        "file-processing"
    ]

    static func isAssistSkillID(_ skillID: String) -> Bool {
        assistSkillIDs.contains(skillID)
    }

    // MARK: - Section Parser

    static func parseSections(from text: String) -> KSkillAssistParsedSections {
        let lines = text.components(separatedBy: "\n")
        var title = ""
        var messageLines: [String] = []
        var checklist: [String] = []
        var requiredInputs: [String] = []
        var nextActions: [String] = []
        var hardBlockedActions: [String] = []

        enum Section { case none, message, checklist, required, next, blocked }
        var currentSection: Section = .none

        for line in lines {
            if line.hasPrefix("## ") {
                title = String(line.dropFirst(3))
                currentSection = .message
            } else if line == "### 준비 체크리스트" || line == "### 확인 체크리스트" {
                currentSection = .checklist
            } else if line == "### 필요한 입력" || line == "### 필요한 정보" {
                currentSection = .required
            } else if line == "### 다음에 할 일" || line == "### 다음 단계" {
                currentSection = .next
            } else if line == "### 직접 진행이 필요한 작업" || line == "### 직접 대신하지 않는 항목" {
                currentSection = .blocked
            } else {
                switch currentSection {
                case .message:
                    if !line.isEmpty || !messageLines.isEmpty { messageLines.append(line) }
                case .checklist:
                    if line.hasPrefix("☐ ") { checklist.append(String(line.dropFirst(2))) }
                    else if line.hasPrefix("- [ ] ") { checklist.append(String(line.dropFirst(6))) }
                    else if line.hasPrefix("- ✅ ") { checklist.append(String(line.dropFirst(5))) }
                case .required:
                    if line.hasPrefix("▸ ") { requiredInputs.append(String(line.dropFirst(2))) }
                    else if line.hasPrefix("- ") { requiredInputs.append(String(line.dropFirst(2))) }
                case .next:
                    if let dotRange = line.range(of: ". "), line.first?.isNumber == true {
                        nextActions.append(String(line[dotRange.upperBound...]))
                    }
                case .blocked:
                    if line.hasPrefix("⚠️ ") { hardBlockedActions.append(String(line.dropFirst(3))) }
                    else if line.hasPrefix("- 🚫 ") { hardBlockedActions.append(String(line.dropFirst(6))) }
                    else if line.hasPrefix("- ") { hardBlockedActions.append(String(line.dropFirst(2))) }
                case .none: break
                }
            }
        }

        let trimmedMessage = messageLines
            .drop(while: { $0.isEmpty })
            .reversed()
            .drop(while: { $0.isEmpty })
            .reversed()
            .joined(separator: "\n")

        return KSkillAssistParsedSections(
            title: title,
            message: trimmedMessage,
            checklist: checklist,
            requiredInputs: requiredInputs,
            nextActions: nextActions,
            hardBlockedActions: hardBlockedActions
        )
    }

    // MARK: - Detection

    static func detectIntent(userMessage: String, skillID: String? = nil) -> KSkillAssistIntent? {
        let lower = userMessage.lowercased()

        if let skillID {
            switch skillID {
            case "transportation-booking": return .transportationBookingAssist
            case "accommodation-planning": return .accommodationAssist
            case "investment-research": return .investmentResearchAssist
            case "news-research": return .newsResearchAssist
            case "travel-planning": return .travelPlanningAssist
            case "business-document": return .businessDocumentAssist
            case "file-processing": return .fileProcessingAssist
            default: break
            }
        }

        // Natural language detection (multilingual: Korean, English, Japanese)
        // Transportation
        if lower.contains("기차") || lower.contains("열차") || lower.contains("버스") ||
           lower.contains("항공") || lower.contains("비행기") || lower.contains("예약") ||
           lower.contains("train") || lower.contains("bus") || lower.contains("flight") ||
           lower.contains("電車") || lower.contains("バス") || lower.contains("航空") {
            return .transportationBookingAssist
        }

        // Accommodation
        if lower.contains("숙박") || lower.contains("호텔") || lower.contains("에어비앤비") ||
           lower.contains("hotel") || lower.contains("accommodation") || lower.contains("airbnb") ||
           lower.contains("ホテル") || lower.contains("宿泊") {
            return .accommodationAssist
        }

        // Investment
        if lower.contains("주가") || lower.contains("주식") || lower.contains("투자") || lower.contains("종목") ||
           lower.contains("stock") || lower.contains("investment") || lower.contains("equity") ||
           lower.contains("株") || lower.contains("投資") {
            return .investmentResearchAssist
        }

        // News
        if lower.contains("뉴스") || lower.contains("기사") || lower.contains("리서치") ||
           lower.contains("news") || lower.contains("article") || lower.contains("research") ||
           lower.contains("ニュース") || lower.contains("記事") {
            return .newsResearchAssist
        }

        // Travel planning
        if lower.contains("여행") || lower.contains("관광") || lower.contains("지도") ||
           lower.contains("travel") || lower.contains("trip") || lower.contains("tourism") ||
           lower.contains("旅行") || lower.contains("観光") {
            return .travelPlanningAssist
        }

        // Business documents
        if lower.contains("회의록") || lower.contains("보고서") || lower.contains("문서") ||
           lower.contains("report") || lower.contains("document") || lower.contains("meeting") ||
           lower.contains("会議") || lower.contains("報告書") {
            return .businessDocumentAssist
        }

        // File processing
        if lower.contains("파일") || lower.contains("이미지") || lower.contains("정리") ||
           lower.contains("file") || lower.contains("image") || lower.contains("process") ||
           lower.contains("ファイル") || lower.contains("画像") {
            return .fileProcessingAssist
        }

        return nil
    }

    // MARK: - Response Builder (JSON-based)

    static func buildAssistResponse(intent: KSkillAssistIntent, userMessage: String) -> KSkillAssistResponse {
        // Find skill ID by intent
        guard let skillID = intentToSkillID(intent) else {
            return fallbackResponse(for: intent)
        }

        // Load from JSON
        if let response = SkillResourceLoader.shared.toKSkillAssistResponse(skillID: skillID) {
            return response
        }

        // Fallback if JSON loading fails
        return fallbackResponse(for: intent)
    }

    // MARK: - Intent to Skill ID Mapping

    private static func intentToSkillID(_ intent: KSkillAssistIntent) -> String? {
        switch intent {
        case .transportationBookingAssist: return "transportation-booking"
        case .accommodationAssist: return "accommodation-planning"
        case .investmentResearchAssist: return "investment-research"
        case .newsResearchAssist: return "news-research"
        case .travelPlanningAssist: return "travel-planning"
        case .businessDocumentAssist: return "business-document"
        case .fileProcessingAssist: return "file-processing"
        }
    }

    // MARK: - Fallback Response (if JSON unavailable)

    private static func fallbackResponse(for intent: KSkillAssistIntent) -> KSkillAssistResponse {
        return KSkillAssistResponse(
            intent: intent,
            title: "Skill Helper",
            message: "I'm here to help. Please share your request and I'll provide guidance without taking action on your behalf.",
            checklist: ["Clarify your objective"],
            nextActions: ["Share details for personalized guidance"],
            hardBlockedActions: ["Automated actions without your direct approval"],
            requiredUserInputs: ["Request details"]
        )
    }

    // MARK: - Markdown Formatter

    static func formatMarkdown(_ response: KSkillAssistResponse) -> String {
        var lines: [String] = []
        lines.append("## \(response.title)")
        lines.append("")
        lines.append(response.message)

        if !response.requiredUserInputs.isEmpty {
            lines.append("")
            lines.append("### 필요한 입력")
            for input in response.requiredUserInputs {
                lines.append("▸ \(input)")
            }
        }

        if !response.checklist.isEmpty {
            lines.append("")
            lines.append("### 준비 체크리스트")
            for item in response.checklist {
                lines.append("☐ \(item)")
            }
        }

        if !response.nextActions.isEmpty {
            lines.append("")
            lines.append("### 다음에 할 일")
            for (idx, action) in response.nextActions.enumerated() {
                lines.append("\(idx + 1). \(action)")
            }
        }

        if !response.hardBlockedActions.isEmpty {
            lines.append("")
            lines.append("### 직접 진행이 필요한 작업")
            for action in response.hardBlockedActions {
                lines.append("⚠️ \(action)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
