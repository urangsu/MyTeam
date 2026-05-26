import Foundation

// Round 249A-KSKILLS-ASSIST: Lifestyle & public-read assist runtime
// Policy: No fake API calls, no auto booking/payment/login
// All skills return checklist + required inputs + blocked actions

// MARK: - Intent

enum KSkillAssistIntent: String, Codable, Sendable {
    case ktxBookingAssist
    case mapPlaceAssist
    case reservationPreparation
    case stockInfoAssist
    case dartDisclosureAssist
    case naverNewsAssist
    case naverBlogResearchAssist
    case lawSearchAssist
    case scholarshipAssist
    case officeReviewAssist
    case fileImageAssist
    case mailSummaryAssist
    case accountReviewAssist
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

enum SkillResultCardType: String, Codable, Sendable {
    case mailSummary
    case pdfSummary
    case stock
    case disclosure
    case ktx
    case map
    case accountReview
    case assist
}

enum SkillChainID: String, Codable, Sendable {
    case stockMoveAnalysis = "stock.move.analysis"
    case mailAction = "mail.action"
    case documentAction = "document.action"
    case tripPlanning = "trip.planning"
    case accountReview = "account.review"
    case research = "research.public"
}

struct ActionSuggestion: Identifiable, Codable, Sendable {
    let id: UUID
    let type: String
    let title: String
    let preview: String
    let requiresApproval: Bool
    let handlerID: ActionHandlerID?

    init(type: String, title: String, preview: String, requiresApproval: Bool = false, handlerID: ActionHandlerID? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.preview = preview
        self.requiresApproval = requiresApproval
        self.handlerID = handlerID
    }
}

struct SkillResultCard: Codable, Sendable {
    let type: SkillResultCardType
    let title: String
    let summary: [String]
    let actionItems: [String]
    let cautions: [String]
    let nextActionButtons: [String]
}

struct SourceReference: Codable, Sendable {
    let title: String
    let kind: String
    let note: String
}

struct SkillVerification: Codable, Sendable {
    let status: String
    let failureCode: String?
    let message: String

    static func verified(sourceCount: Int) -> SkillVerification {
        SkillVerification(
            status: "verified",
            failureCode: nil,
            message: "외부 근거 \(sourceCount)개를 확인해 카드에 반영했습니다. 금융/투자 판단은 참고 정보이며 최종 결정은 사용자가 확인해야 합니다."
        )
    }

    static func partiallyVerified(sourceCount: Int) -> SkillVerification {
        SkillVerification(
            status: "partially_verified",
            failureCode: nil,
            message: "사용자가 제공한 자료 \(sourceCount)개를 근거로 카드화했습니다. 외부 시스템 조회나 자동 등록은 하지 않았습니다."
        )
    }

    static let connectorUnavailable = SkillVerification(
        status: "connector_unavailable",
        failureCode: "connector_unavailable",
        message: "필요한 외부 커넥터가 아직 사용할 수 없어, 지금 가능한 대체 실행과 다음 행동을 카드로 남겼습니다."
    )

    static let userInputRequired = SkillVerification(
        status: "blocked",
        failureCode: "user_input_required",
        message: "사용자 자료 또는 조건이 필요합니다. 확인되지 않은 외부 조회 결과는 만들지 않았습니다."
    )
}

enum SkillExecutionMode: String, Codable, Sendable {
    case assistOnly
    case readOnlyLookup
    case userProvidedSourceAnalysis
    case approvalRequiredAction
}

// MARK: - Parsed Sections

struct KSkillAssistParsedSections: Sendable {
    let title: String
    let message: String
    let checklist: [String]
    let requiredInputs: [String]
    let nextActions: [String]
    let chainStatusLines: [String]
    let actionSuggestionLines: [String]
    let connectorStatusLines: [String]
    let attachmentStatusLines: [String]
    let hardBlockedActions: [String]
}

// MARK: - Runtime

enum KSkillAssistRuntime {

    // MARK: - Skill ID Registry

    private static let assistSkillIDs: Set<String> = [
        "korean.ktx-booking",
        "korean.map-place",
        "korean.reservation-preparation",
        "korean.stock-info",
        "korean.dart",
        "korean.naver-news",
        "korean.naver-blog-research",
        "korean.law-search",
        "korean.scholarship",
        "korean.office-review-assist",
        "korean.file-image-assist",
        "korean.mail-summary-assist",
        "korean.account-review-assist"
    ]

    static func isAssistSkillID(_ skillID: String) -> Bool {
        assistSkillIDs.contains(skillID)
    }

    nonisolated static func skillID(for intent: KSkillAssistIntent) -> String {
        switch intent {
        case .ktxBookingAssist:
            return "korean.ktx-booking"
        case .mapPlaceAssist:
            return "korean.map-place"
        case .reservationPreparation:
            return "korean.reservation-preparation"
        case .stockInfoAssist:
            return "korean.stock-info"
        case .dartDisclosureAssist:
            return "korean.dart"
        case .naverNewsAssist:
            return "korean.naver-news"
        case .naverBlogResearchAssist:
            return "korean.naver-blog-research"
        case .lawSearchAssist:
            return "korean.law-search"
        case .scholarshipAssist:
            return "korean.scholarship"
        case .officeReviewAssist:
            return "korean.office-review-assist"
        case .fileImageAssist:
            return "korean.file-image-assist"
        case .mailSummaryAssist:
            return "korean.mail-summary-assist"
        case .accountReviewAssist:
            return "korean.account-review-assist"
        }
    }

    // MARK: - Section Parser

    static func parseSections(from text: String) -> KSkillAssistParsedSections {
        let lines = text.components(separatedBy: "\n")
        var title = ""
        var messageLines: [String] = []
        var checklist: [String] = []
        var requiredInputs: [String] = []
        var nextActions: [String] = []
        var chainStatusLines: [String] = []
        var actionSuggestionLines: [String] = []
        var connectorStatusLines: [String] = []
        var attachmentStatusLines: [String] = []
        var hardBlockedActions: [String] = []

        enum Section { case none, message, checklist, required, next, blocked, chain, actions, connectors, attachments }
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
            } else if line == "### 실행 체인" {
                currentSection = .chain
            } else if line == "### 제안 액션" {
                currentSection = .actions
            } else if line == "### 커넥터 상태" {
                currentSection = .connectors
            } else if line == "### 확인한 첨부" {
                currentSection = .attachments
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
                case .chain:
                    if !line.isEmpty {
                        chainStatusLines.append(line)
                    }
                case .actions:
                    if !line.isEmpty {
                        actionSuggestionLines.append(line)
                    }
                case .connectors:
                    if !line.isEmpty {
                        connectorStatusLines.append(line)
                    }
                case .attachments:
                    if !line.isEmpty {
                        attachmentStatusLines.append(line)
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
            chainStatusLines: chainStatusLines,
            actionSuggestionLines: actionSuggestionLines,
            connectorStatusLines: connectorStatusLines,
            attachmentStatusLines: attachmentStatusLines,
            hardBlockedActions: hardBlockedActions
        )
    }

    // MARK: - Detection

    nonisolated static func detectIntent(userMessage: String, skillID: String? = nil) -> KSkillAssistIntent? {
        let lower = userMessage.lowercased()

        if let skillID {
            switch skillID {
            case "korean.ktx-booking", "ktx-booking-assist": return .ktxBookingAssist
            case "korean.dart", "dart-disclosure-assist": return .dartDisclosureAssist
            case "korean.stock", "stock-info-assist": return .stockInfoAssist
            case "korean.naver-news": return .naverNewsAssist
            case "korean.naver-blog-research": return .naverBlogResearchAssist
            case "korean.law-search": return .lawSearchAssist
            case "korean.scholarship": return .scholarshipAssist
            case "korean.office-review-assist": return .officeReviewAssist
            case "korean.file-image-assist": return .fileImageAssist
            case "korean.mail-summary-assist", "korean.mail-summary", "mail-summary-assist": return .mailSummaryAssist
            case "korean.account-review-assist", "korean.account-review", "account-review-assist": return .accountReviewAssist
            case "map-place-assist", "reservation-preparation": return .mapPlaceAssist
            default: break
            }
        }

        // Natural language detection
        if lower.contains("메일") || lower.contains("이메일") || lower.contains("email") || lower.contains("gmail")
            || lower.contains("받은편지") || lower.contains("받은 메일") {
            return .mailSummaryAssist
        }
        if lower.contains("계좌") || lower.contains("거래내역") || lower.contains("카드내역") || lower.contains("입출금")
            || lower.contains("정산") || lower.contains("영수증") || lower.contains("증빙") || lower.contains("세무") {
            return .accountReviewAssist
        }
        if lower.contains("pdf") || lower.contains("docx") || lower.contains("pptx") || lower.contains("xlsx")
            || lower.contains("hwp") || lower.contains("첨부") || lower.contains("파일") || lower.contains("문서 요약")
            || lower.contains("문서요약") || lower.contains("방금 문서") || lower.contains("이미지 읽") || lower.contains("ocr") {
            return .fileImageAssist
        }
        if lower.contains("ktx") || lower.contains("srt") || lower.contains("기차 예매") || lower.contains("열차 예매") {
            return .ktxBookingAssist
        }
        if lower.contains("주가") || lower.contains("주식") || lower.contains("종목") || lower.contains("시세")
            || lower.contains("삼성전자") || lower.contains("삼전") || lower.contains("sk하이닉스")
            || lower.contains("하이닉스") || lower.contains("엔비디아") || lower.contains("테슬라")
            || lower.contains("애플") || lower.contains("왜 떨어") || lower.contains("왜 올랐")
            || lower.contains("급락") || lower.contains("급등") {
            return .stockInfoAssist
        }
        if lower.contains("dart") || lower.contains("공시") || lower.contains("사업보고서") {
            return .dartDisclosureAssist
        }
        if lower.contains("네이버 뉴스") || lower.contains("naver 뉴스") || lower.contains("뉴스 검색") {
            return .naverNewsAssist
        }
        if lower.contains("블로그") || lower.contains("리뷰") || lower.contains("후기 조사") {
            return .naverBlogResearchAssist
        }
        if lower.contains("법령") || lower.contains("법률") || lower.contains("판례") || lower.contains("법원") {
            return .lawSearchAssist
        }
        if lower.contains("장학금") || lower.contains("국가장학") || lower.contains("복지급여") {
            return .scholarshipAssist
        }
        if lower.contains("맛집") || lower.contains("식당 예약") || lower.contains("숙박 예약") || lower.contains("장소 찾아줘") {
            return .mapPlaceAssist
        }
        if lower.contains("예약") || lower.contains("reservat") {
            return .reservationPreparation
        }
        if lower.contains("회의록") || lower.contains("액션아이템") || lower.contains("보고서") || lower.contains("파일명")
            || lower.contains("요약해") || lower.contains("정리해") {
            return .officeReviewAssist
        }
        return nil
    }

    // MARK: - Response Builder

    static func buildAssistResponse(intent: KSkillAssistIntent, userMessage: String) -> KSkillAssistResponse {
        switch intent {

        case .ktxBookingAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "KTX / SRT 예매 도우미",
                message: "KTX 예매 확정이나 결제는 대신하지 않습니다. 출발·도착·날짜·시간대 조건을 정리하고 예매 전 확인할 체크리스트를 만들어드릴게요.",
                checklist: [
                    "출발역과 도착역 확인",
                    "여행 날짜와 희망 시간대 (아침/오전/오후/저녁)",
                    "인원수와 좌석 종류 (일반/특실)",
                    "Korail 회원 로그인 상태 사전 확인",
                    "환불·변경 규정 확인 (출발 전 1일 이내 수수료)",
                    "특가/할인 적용 조건 확인"
                ],
                nextActions: [
                    "Korail 앱(코레일톡) 또는 SRT 앱에서 직접 조회 및 예매",
                    "예매 조건 정리가 필요하면 출발역·도착역·날짜·인원을 알려주세요"
                ],
                hardBlockedActions: [
                    "자동 로그인 대행",
                    "자동 좌석 예매 확정",
                    "결제 정보 처리",
                    "캡차 우회"
                ],
                requiredUserInputs: ["출발역", "도착역", "날짜", "시간대", "인원수"]
            )

        case .mapPlaceAssist, .reservationPreparation:
            return KSkillAssistResponse(
                intent: intent,
                title: "장소·예약 준비 도우미",
                message: "제가 대신 예약하거나 개인정보를 제출하진 않아요. 장소명이나 링크를 주시면 비교 기준, 확인할 항목, 복사해서 쓸 검색 조건까지 정리해드릴게요.",
                checklist: [
                    "방문 목적과 인원 확인",
                    "영업 시간 및 정기 휴무일 확인",
                    "예약 필수 여부 (전화/온라인/앱)",
                    "주차 가능 여부",
                    "위치·교통편 확인",
                    "취소·변경 정책 확인"
                ],
                nextActions: [
                    "장소명·방문일·인원수를 알려주시면 지도앱에 바로 넣을 검색 조건으로 정리",
                    "링크를 주시면 장단점과 예약 전 확인 항목을 카드로 정리"
                ],
                hardBlockedActions: [
                    "자동 예약 확정",
                    "결제 정보 처리",
                    "개인정보 제출"
                ],
                requiredUserInputs: ["장소명 또는 링크", "방문 일시", "인원수"]
            )

        case .stockInfoAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "주가 정보 도우미",
                message: "매수·매도 판단을 대신 확정하지는 않아요. 종목명, 기사, 공시, PDF를 주시면 숫자·이슈·리스크를 분리해서 검토 카드로 정리해드릴게요.",
                checklist: [
                    "종목 기본 정보 확인 (업종, 시가총액)",
                    "최근 실적 및 공시 확인 (DART)",
                    "PER / PBR / ROE 등 밸류에이션 지표",
                    "52주 고가/저가 대비 현재 위치",
                    "주요 리스크 요인 파악",
                    "배당 여부 및 배당수익률 확인"
                ],
                nextActions: [
                    "종목명만 주시면 확인해야 할 시세·실적·공시 체크 항목을 카드로 정리",
                    "기사나 공시를 붙여주시면 핵심 사실, 숫자, 리스크를 요약"
                ],
                hardBlockedActions: [
                    "매수/매도 확정 추천",
                    "수익 보장",
                    "투자자문 확정 표현"
                ],
                requiredUserInputs: ["종목명 또는 티커", "분석 목적 (단기/장기/배당)"]
            )

        case .dartDisclosureAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "DART 공시 도우미",
                message: "공시를 조회한 척하지 않고, 사용자가 준 공시 PDF·본문·링크 기준으로만 정리합니다. 자료를 주시면 공시 종류, 핵심 숫자, 위험 포인트를 카드로 남겨드릴게요.",
                checklist: [
                    "공시 종류 확인 (사업보고서/분기보고서/수시공시)",
                    "보고 기간 및 작성일 확인",
                    "주요 재무지표 (매출/영업이익/순이익)",
                    "주요 위험 요인 섹션",
                    "관계회사 및 특수관계인 거래",
                    "감사인 의견"
                ],
                nextActions: [
                    "공시 PDF나 본문을 첨부하면 사업보고서/분기보고서/수시공시로 분류",
                    "숫자·날짜·위험요인을 따로 뽑아 후속 질문할 수 있게 저장"
                ],
                hardBlockedActions: [
                    "실제 DART API 조회한 척하기",
                    "투자자문 확정 표현"
                ],
                requiredUserInputs: ["종목명 또는 기업명", "공시 내용 또는 링크"]
            )

        case .naverNewsAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "뉴스 리서치 도우미",
                message: "검색 결과를 꾸며내지 않습니다. 기사 링크나 본문을 주시면 핵심 사실, 주장, 확인이 필요한 대목을 분리해 정리해드릴게요.",
                checklist: [
                    "출처 및 보도 날짜 확인",
                    "핵심 사실과 주장 구분",
                    "복수 매체 교차 확인",
                    "인용 출처 확인",
                    "광고성/편향 여부 파악"
                ],
                nextActions: [
                    "기사 링크나 본문을 붙여넣으면 요약 카드로 정리",
                    "여러 기사를 주시면 공통 사실과 서로 다른 주장을 비교"
                ],
                hardBlockedActions: [
                    "실시간 검색 결과 꾸며내기",
                    "원문 없는 기사 내용 인용"
                ],
                requiredUserInputs: ["기사 링크 또는 본문"]
            )

        case .naverBlogResearchAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "블로그 리서치 도우미",
                message: "후기나 순위를 임의로 만들지 않습니다. 참고 링크나 본문을 주시면 공통 포인트를 뽑고 블로그 초안 구조로 정리해드릴게요.",
                checklist: [
                    "조사 주제와 목적 명확히 하기",
                    "참고할 키워드 목록 작성",
                    "신뢰할 출처 기준 정하기",
                    "블로그 글 구조 (도입/본론/결론) 계획"
                ],
                nextActions: [
                    "네이버 블로그 또는 인플루언서 검색에서 직접 조사",
                    "참고할 링크나 본문을 주시면 구조화하고 초안을 만들어드릴 수 있습니다"
                ],
                hardBlockedActions: [
                    "순위/최신성 꾸며내기",
                    "원문 없는 후기 생성"
                ],
                requiredUserInputs: ["주제", "참고 링크 또는 본문 (선택)"]
            )

        case .lawSearchAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "법령·정부정보 도우미",
                message: "최신 법령을 확인한 것처럼 단정하지 않습니다. 법령명, 공고문, 안내문을 주시면 자격조건·준비서류·주의사항을 분리해 정리해드릴게요.",
                checklist: [
                    "적용 법령의 시행일 확인",
                    "관할 기관 및 문의처 확인",
                    "예외 조항 및 특례 여부",
                    "최신 개정 여부 확인 (law.go.kr)",
                    "실제 사례 적용 시 전문가 상담 권장"
                ],
                nextActions: [
                    "국가법령정보센터(law.go.kr)에서 직접 확인",
                    "관련 공문서나 안내문을 붙여주시면 핵심 내용을 정리해드릴 수 있습니다"
                ],
                hardBlockedActions: [
                    "법률 자문 확정 표현",
                    "최신 법령 조회한 척하기",
                    "판례 내용 꾸며내기"
                ],
                requiredUserInputs: ["법령명 또는 안내문", "질문 내용"]
            )

        case .scholarshipAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "장학금·복지급여 도우미",
                message: "최신 공고를 본 것처럼 단정하지 않습니다. 공고문이나 링크를 주시면 자격조건, 신청기간, 준비서류, 놓치기 쉬운 조건을 카드로 정리해드릴게요.",
                checklist: [
                    "지원 자격 조건 (소득분위/학점/재학 여부)",
                    "신청 기간 및 접수처 확인",
                    "제출 서류 목록",
                    "지급 방식과 금액",
                    "중복 수혜 제한 여부",
                    "연장 신청 조건"
                ],
                nextActions: [
                    "한국장학재단(kosaf.go.kr) 또는 복지로(bokjiro.go.kr) 직접 확인",
                    "공고문을 붙여주시면 자격조건과 서류 목록을 정리해드릴 수 있습니다"
                ],
                hardBlockedActions: [
                    "지원 가능 여부 확정",
                    "최신 공고 존재한다고 단정"
                ],
                requiredUserInputs: ["장학금/급여 종류", "공고문 또는 링크 (선택)"]
            )

        case .officeReviewAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "사무 검토 도우미",
                message: "검토할 파일이나 텍스트를 주시면 회의록 액션아이템, 파일명 정리, 보고서 말투 정리를 바로 도와드릴 수 있어요.",
                checklist: [
                    "검토 대상 문서 확인 (회의록/보고서/파일명 목록)",
                    "검토 기준 및 목적 명확히 하기",
                    "민감 정보(계좌/개인정보) 포함 여부 확인"
                ],
                nextActions: [
                    "문서 내용을 붙여주시거나 파일을 올려주세요",
                    "회의록 → 액션아이템 추출, 보고서 → 말투 정리, 파일 → 네이밍 제안"
                ],
                hardBlockedActions: [
                    "원본 파일 자동 수정",
                    "외부 업로드"
                ],
                requiredUserInputs: ["검토 문서 또는 텍스트"]
            )

        case .fileImageAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "파일·이미지 도우미",
                message: "요약할 대상을 먼저 지목해야 합니다. 파일을 올리거나, 최근 생성 문서 중 어떤 것을 볼지 말해주시면 그 대상 기준으로 요약·검토를 진행할게요.",
                checklist: [
                    "파일 형식 확인 (PDF/텍스트/이미지/스프레드시트)",
                    "대상 파일 또는 최근 문서명 확인",
                    "파일 내 민감 정보 여부 확인",
                    "처리 목적 결정 (요약/검토/변환/표 추출)"
                ],
                nextActions: [
                    "요약할 파일을 첨부하거나 문서명을 알려주세요",
                    "요약, 표 추출, 핵심 리스크 검토처럼 원하는 결과 형태를 같이 말해주세요"
                ],
                hardBlockedActions: [
                    "대상 없는 상태에서 '방금 문서'라고 단정",
                    "파일 외부 업로드",
                    "자동 삭제"
                ],
                requiredUserInputs: ["파일 또는 텍스트", "처리 목적"]
            )

        case .mailSummaryAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "메일 요약 도우미",
                message: "메일함에 자동 접속한 척하지 않습니다. 메일 본문, 캡처, eml/txt 파일, 또는 복사한 대화 내용을 주시면 핵심 요약과 해야 할 일 카드로 정리합니다.",
                checklist: [
                    "보낸 사람, 날짜, 제목 확인",
                    "요청 사항과 마감일 분리",
                    "첨부파일/링크 여부 확인",
                    "답장 필요 여부와 톤 결정",
                    "개인정보나 계약 정보 포함 여부 확인"
                ],
                nextActions: [
                    "메일 본문을 붙여넣거나 파일로 첨부해주세요",
                    "요약만 필요한지, 답장 초안까지 필요한지 같이 말해주세요"
                ],
                hardBlockedActions: [
                    "메일 계정 자동 로그인",
                    "받은편지함 임의 조회",
                    "사용자 확인 없는 메일 발송"
                ],
                requiredUserInputs: ["메일 본문 또는 파일", "원하는 결과 (요약/할 일/답장 초안)"]
            )

        case .accountReviewAssist:
            return KSkillAssistResponse(
                intent: intent,
                title: "계좌·증빙 검토 도우미",
                message: "계좌나 세무 자료를 실제로 조회한 척하지 않습니다. 거래내역 CSV/XLSX, 영수증 이미지, 정산표를 주시면 이상 거래 후보와 정리 기준을 표시합니다.",
                checklist: [
                    "기간과 계좌/카드 범위 확인",
                    "입금, 출금, 수수료, 환불 항목 분리",
                    "중복 결제 또는 누락 후보 확인",
                    "증빙 필요 항목 표시",
                    "세무 판단은 전문가 확인 대상으로 분리"
                ],
                nextActions: [
                    "거래내역 파일이나 표를 첨부해주세요",
                    "개인정보가 있으면 가린 뒤 올려도 됩니다",
                    "목표를 알려주세요: 정산, 누락 확인, 증빙 목록, 이상 거래 후보"
                ],
                hardBlockedActions: [
                    "은행/카드 계정 자동 로그인",
                    "세무 신고 대행",
                    "최종 세무 판단 확정"
                ],
                requiredUserInputs: ["거래내역 또는 영수증 자료", "검토 기간", "검토 목적"]
            )
        }
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

// MARK: - Skill Run Engine

struct KSkillRunResult: Sendable {
    let roomID: UUID
    let intent: KSkillAssistIntent
    let skillID: String
    let title: String
    let card: SkillResultCard
    let sourceRefs: [SourceReference]
    let verification: SkillVerification
    let markdown: String
    let requiredInputs: [String]
    let blockedActions: [String]
    let artifactID: String?
}

enum SkillOrchestrator {
    static func route(
        message: String,
        roomID: UUID,
        attachments: [ChatAttachment] = [],
        agentID: String? = nil,
        matchedSkills: [SkillManifest] = []
    ) async -> (result: KSkillRunResult, evidence: ToolEvidenceResult)? {
        await KSkillRunEngine.runPrimary(
            userMessage: message,
            roomID: roomID,
            attachments: attachments,
            agentID: agentID,
            matchedSkills: matchedSkills
        )
    }
}

enum KSkillRunEngine {
    static func run(userMessage: String, roomID: UUID, matchedSkills: [SkillManifest] = []) -> KSkillRunResult? {
        guard let intent = detectIntent(userMessage: userMessage, matchedSkills: matchedSkills) else {
            return nil
        }

        let response = KSkillAssistRuntime.buildAssistResponse(intent: intent, userMessage: userMessage)
        let card = card(for: response, evidence: .empty)
        return KSkillRunResult(
            roomID: roomID,
            intent: intent,
            skillID: KSkillAssistRuntime.skillID(for: intent),
            title: response.title,
            card: card,
            sourceRefs: sourceRefs(for: response, evidence: .empty),
            verification: .userInputRequired,
            markdown: formatCardMarkdown(response: response, card: card),
            requiredInputs: response.requiredUserInputs,
            blockedActions: response.hardBlockedActions,
            artifactID: nil
        )
    }

    static func runPrimary(
        userMessage: String,
        roomID: UUID,
        attachments: [ChatAttachment] = [],
        agentID: String? = nil,
        matchedSkills: [SkillManifest] = []
    ) async -> (result: KSkillRunResult, evidence: ToolEvidenceResult)? {
        guard let intent = detectIntent(userMessage: userMessage, matchedSkills: matchedSkills) else {
            return nil
        }

        let response = KSkillAssistRuntime.buildAssistResponse(intent: intent, userMessage: userMessage)
        let chainID = chainID(for: intent)
        let mode = executionMode(for: intent)
        let health = ConnectorHealth.current()
        let shouldGatherEvidence = shouldGatherEvidence(for: intent, mode: mode, health: health)
        let lookupQuery = evidenceQuery(for: intent, userMessage: userMessage)
        let policy = evidencePolicy(for: intent, userMessage: lookupQuery)
        let gatheredEvidence = shouldGatherEvidence ? await ToolEvidenceService.gather(for: lookupQuery, policy: policy) : .empty
        let evidence = mergeEvidence(gatheredEvidence, attachments: attachments)
        let verification = verificationStatus(
            intent: intent,
            mode: mode,
            health: health,
            evidence: evidence,
            attachments: attachments
        )
        let baseSuggestions = actionSuggestions(for: intent, evidence: evidence, attachments: attachments)
        let postTurnSuggestions = await PostTurnIntelligenceEngine.shared.suggestNextActions(
            roomID: roomID,
            latestUserText: userMessage,
            assistantText: response.message,
            chainRun: nil,
            connectorHealth: health
        )
        let mergedSuggestions = dedupeActionSuggestions(baseSuggestions + postTurnSuggestions)
        let chainRun = await ChainOrchestrator.makeRun(
            roomID: roomID,
            chainID: chainID,
            userMessage: userMessage,
            attachments: attachments,
            evidence: evidence,
            actions: mergedSuggestions,
            health: health
        )
        let card = card(for: response, evidence: evidence, attachments: attachments, chainID: chainID)
        let markdown = formatCardMarkdown(
            response: response,
            card: card,
            evidence: evidence,
            verification: verification,
            mode: mode,
            health: health,
            chainID: chainID,
            attachments: attachments,
            actionSuggestions: mergedSuggestions,
            chainRun: chainRun
        )
        let result = KSkillRunResult(
            roomID: roomID,
            intent: intent,
            skillID: KSkillAssistRuntime.skillID(for: intent),
            title: response.title,
            card: card,
            sourceRefs: sourceRefs(for: response, evidence: evidence),
            verification: verification,
            markdown: markdown,
            requiredInputs: response.requiredUserInputs,
            blockedActions: response.hardBlockedActions,
            artifactID: nil
        )
        return (result, evidence)
    }

    @MainActor
    static func writeResultArtifact(
        _ result: KSkillRunResult,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> IndexedArtifact? {
        let workflowID = manager.currentWorkflowID ?? UUID()
        let markdown = result.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !markdown.isEmpty else { return nil }

        let filename = outputFilename(for: result)
        let fileURL: URL
        do {
            fileURL = try safeWritableWorkspaceURL(
                filename: filename,
                context: ToolExecutionContext.current(workflowID: workflowID, roomID: roomID)
            )
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            AppLog.error("[KSkillRunEngine] skill card artifact write failed: \(error.localizedDescription)")
            return nil
        }

        let savedFilename = fileURL.lastPathComponent
        let contentHash = StableContentHash.sha256Hex(markdown)
        let preview = String(markdown.prefix(220))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: workflowID.uuidString,
            title: result.title,
            type: .text,
            filename: savedFilename,
            relativePath: savedFilename,
            preview: preview,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            contentHash: contentHash,
            fileSizeBytes: Int64(markdown.utf8.count),
            roomID: roomID.uuidString
        )

        await ArtifactStore.shared.registerArtifact(artifact)
        ChainRunStore.shared.appendArtifact(artifact.id, roomID: roomID)
        manager.addRecentArtifactIndexEntry(
            RecentArtifactIndexEntry(
                artifactID: artifact.id,
                roomID: roomID,
                filename: savedFilename,
                artifactType: artifact.type.rawValue,
                createdAt: Date(),
                contentHash: contentHash,
                fileSizeBytes: Int64(markdown.utf8.count)
            )
        )
        NotificationCenter.default.post(
            name: .workflowCompleted,
            object: nil,
            userInfo: [
                "workflowID": workflowID.uuidString,
                "roomID": roomID.uuidString,
                "artifacts": [artifact]
            ]
        )
        return artifact
    }

    private static func outputFilename(for result: KSkillRunResult) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let skillStem = result.skillID
            .replacingOccurrences(of: "korean.", with: "")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        return "skill-card-\(skillStem)-\(stamp).md"
    }

    private static func detectIntent(userMessage: String, matchedSkills: [SkillManifest]) -> KSkillAssistIntent? {
        let matchedIntent = matchedSkills
            .compactMap { KSkillAssistRuntime.detectIntent(userMessage: userMessage, skillID: $0.id) }
            .first
        return matchedIntent ?? KSkillAssistRuntime.detectIntent(userMessage: userMessage)
    }

    private static func executionMode(for intent: KSkillAssistIntent) -> SkillExecutionMode {
        switch intent {
        case .stockInfoAssist, .dartDisclosureAssist, .naverNewsAssist, .naverBlogResearchAssist:
            return .readOnlyLookup
        case .mailSummaryAssist, .fileImageAssist, .accountReviewAssist, .officeReviewAssist:
            return .userProvidedSourceAnalysis
        case .ktxBookingAssist, .mapPlaceAssist, .reservationPreparation:
            return .assistOnly
        case .lawSearchAssist, .scholarshipAssist:
            return .readOnlyLookup
        }
    }

    private static func chainID(for intent: KSkillAssistIntent) -> SkillChainID {
        switch intent {
        case .stockInfoAssist, .dartDisclosureAssist:
            return .stockMoveAnalysis
        case .mailSummaryAssist:
            return .mailAction
        case .fileImageAssist, .officeReviewAssist:
            return .documentAction
        case .ktxBookingAssist, .mapPlaceAssist, .reservationPreparation:
            return .tripPlanning
        case .accountReviewAssist:
            return .accountReview
        case .naverNewsAssist, .naverBlogResearchAssist, .lawSearchAssist, .scholarshipAssist:
            return .research
        }
    }

    private static func shouldGatherEvidence(
        for intent: KSkillAssistIntent,
        mode: SkillExecutionMode,
        health: ConnectorHealth
    ) -> Bool {
        guard mode == .readOnlyLookup else { return false }
        switch intent {
        case .stockInfoAssist:
            return health.stockQuote == .available
        case .dartDisclosureAssist:
            return health.dartSearch == .available
        case .naverNewsAssist, .naverBlogResearchAssist, .lawSearchAssist, .scholarshipAssist:
            return health.newsSearch == .available
        default:
            return false
        }
    }

    private static func evidenceQuery(for intent: KSkillAssistIntent, userMessage: String) -> String {
        switch intent {
        case .stockInfoAssist:
            return "\(userMessage) 오늘 주가 등락률 관련 뉴스 공시 원인"
        case .dartDisclosureAssist:
            return "\(userMessage) DART 공시 최근 이슈"
        case .naverNewsAssist, .naverBlogResearchAssist:
            return "\(userMessage) 최신 뉴스 출처"
        case .lawSearchAssist:
            return "\(userMessage) 법령 조문 출처"
        case .scholarshipAssist:
            return "\(userMessage) 장학금 모집요강 출처"
        default:
            return userMessage
        }
    }

    private static func evidencePolicy(for intent: KSkillAssistIntent, userMessage: String) -> ToolPolicyDecision {
        let base = ToolPolicy.evaluate(userMessage)
        switch intent {
        case .stockInfoAssist:
            return ToolPolicyDecision(
                needsTool: true,
                needsWeb: true,
                needsFinance: true,
                needsURLFetch: base.needsURLFetch,
                needsCurrentTime: true,
                recommendedTools: Array(Set(base.recommendedTools + ["finance_quote", "web_search", "disclosure_search"])).sorted(),
                reason: "stock move analysis chain"
            )
        case .dartDisclosureAssist, .naverNewsAssist, .naverBlogResearchAssist, .lawSearchAssist, .scholarshipAssist:
            return ToolPolicyDecision(
                needsTool: true,
                needsWeb: true,
                needsFinance: base.needsFinance,
                needsURLFetch: base.needsURLFetch,
                needsCurrentTime: base.needsCurrentTime,
                recommendedTools: Array(Set(base.recommendedTools + ["web_search"])).sorted(),
                reason: "public research chain"
            )
        default:
            return base
        }
    }

    private static func mergeEvidence(_ evidence: ToolEvidenceResult, attachments: [ChatAttachment]) -> ToolEvidenceResult {
        guard !attachments.isEmpty else { return evidence }
        let attachmentSections = attachments.compactMap { attachment -> String? in
            guard let text = attachment.textContent?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return "[첨부자료]\n파일명: \(attachment.fileName)\n상태: 텍스트 추출 결과 없음"
            }
            return """
            [첨부자료]
            파일명: \(attachment.fileName)
            내용 미리보기:
            \(String(text.prefix(2_000)))
            """
        }
        let attachmentContext = attachmentSections.joined(separator: "\n\n")
        let context = [evidence.promptContext, attachmentContext]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        return ToolEvidenceResult(
            promptContext: context,
            sources: evidence.sources + attachmentAgentSources(attachments)
        )
    }

    private static func verificationStatus(
        intent: KSkillAssistIntent,
        mode: SkillExecutionMode,
        health: ConnectorHealth,
        evidence: ToolEvidenceResult,
        attachments: [ChatAttachment]
    ) -> SkillVerification {
        if !evidence.sources.isEmpty {
            return mode == .readOnlyLookup
                ? .verified(sourceCount: evidence.sources.count)
                : .partiallyVerified(sourceCount: evidence.sources.count)
        }
        if !attachments.isEmpty {
            return .partiallyVerified(sourceCount: attachments.count)
        }
        if mode == .readOnlyLookup {
            return .connectorUnavailable
        }
        return .userInputRequired
    }

    private static func attachmentAgentSources(_ attachments: [ChatAttachment]) -> [AgentWindowManager.SourceReference] {
        attachments.map {
            AgentWindowManager.SourceReference(
                title: $0.fileName,
                url: $0.localPath ?? "attachment://\($0.id.uuidString)",
                provider: "UserAttachment",
                accessedAt: Date()
            )
        }
    }

    private static func card(
        for response: KSkillAssistResponse,
        evidence: ToolEvidenceResult,
        attachments: [ChatAttachment] = [],
        chainID: SkillChainID? = nil
    ) -> SkillResultCard {
        var summary = [response.message]
        if !evidence.promptContext.isEmpty {
            summary.append("확인한 근거를 바탕으로 요약, 해야 할 일, 주의점을 분리했습니다.")
        }
        if !attachments.isEmpty {
            summary.append("첨부 \(attachments.count)개를 이 방의 자료로 묶어 카드에 반영했습니다.")
        }
        return SkillResultCard(
            type: cardType(for: response.intent),
            title: response.title,
            summary: summary,
            actionItems: actionItems(for: response.intent, requiredInputs: response.requiredUserInputs, attachments: attachments),
            cautions: response.hardBlockedActions,
            nextActionButtons: nextActionButtons(for: response.intent, chainID: chainID)
        )
    }

    private static func cardType(for intent: KSkillAssistIntent) -> SkillResultCardType {
        switch intent {
        case .mailSummaryAssist:
            return .mailSummary
        case .fileImageAssist, .officeReviewAssist:
            return .pdfSummary
        case .stockInfoAssist:
            return .stock
        case .dartDisclosureAssist:
            return .disclosure
        case .ktxBookingAssist:
            return .ktx
        case .mapPlaceAssist, .reservationPreparation:
            return .map
        case .accountReviewAssist:
            return .accountReview
        default:
            return .assist
        }
    }

    private static func sourceRefs(for response: KSkillAssistResponse, evidence: ToolEvidenceResult) -> [SourceReference] {
        let evidenceRefs = evidence.sources.map {
            SourceReference(title: $0.title, kind: $0.provider, note: $0.url)
        }
        if !evidenceRefs.isEmpty { return evidenceRefs }
        return [
            SourceReference(
                title: "사용자 입력",
                kind: "user_message",
                note: response.requiredUserInputs.isEmpty
                    ? "현재 요청만으로 안내 카드를 생성했습니다."
                    : "자료나 조건이 들어오면 같은 방에서 실행 결과 카드로 이어집니다."
            )
        ]
    }

    private static func actionItems(
        for intent: KSkillAssistIntent,
        requiredInputs: [String],
        attachments: [ChatAttachment]
    ) -> [String] {
        if !attachments.isEmpty {
            switch intent {
            case .mailSummaryAssist:
                return ["요청사항 추출", "날짜·시간 후보 확인", "답장 초안 만들기", "할 일 카드로 저장"]
            case .fileImageAssist, .officeReviewAssist:
                return ["핵심 요약", "숫자·날짜 추출", "마감·위험 포인트 확인", "문서 artifact 저장"]
            case .accountReviewAssist:
                return ["거래내역 정규화", "중복·이상 후보 표시", "증빙 필요 항목 정리", "정산 메일 초안"]
            default:
                break
            }
        }
        return requiredInputs.map { "\($0) 알려주기" }
    }

    private static func nextActionButtons(for intent: KSkillAssistIntent, chainID: SkillChainID? = nil) -> [String] {
        switch intent {
        case .mailSummaryAssist:
            return ["캘린더 초안", "답장 초안", "할 일로 저장"]
        case .fileImageAssist:
            return ["요약 카드", "마감 추출", "체크리스트"]
        case .stockInfoAssist:
            return ["원인 후보", "뉴스 근거", "공시 확인"]
        case .dartDisclosureAssist:
            return ["공시 PDF 올리기", "숫자 뽑기", "리스크 정리"]
        case .ktxBookingAssist:
            return ["역 후보", "검색 조건 복사", "일정 초안"]
        case .mapPlaceAssist, .reservationPreparation:
            return ["장소 링크 붙여넣기", "비교 기준", "예약 체크"]
        case .accountReviewAssist:
            return ["거래내역 올리기", "이상 후보", "증빙 목록"]
        default:
            return ["자료 붙여넣기", "카드로 저장", "체크리스트"]
        }
    }

    private static func formatCardMarkdown(
        response: KSkillAssistResponse,
        card: SkillResultCard,
        evidence: ToolEvidenceResult = .empty,
        verification: SkillVerification = .userInputRequired,
        mode: SkillExecutionMode = .assistOnly,
        health: ConnectorHealth = .current(),
        chainID: SkillChainID? = nil,
        attachments: [ChatAttachment] = [],
        actionSuggestions: [ActionSuggestion] = [],
        chainRun: ChainRun? = nil
    ) -> String {
        var lines = KSkillAssistRuntime.formatMarkdown(response)
            .components(separatedBy: "\n")

        if let chainID {
            lines.append("")
            lines.append("### 실행 체인")
            lines.append("- \(chainID.rawValue)")
            if let chainRun {
                lines.append("- 상태: \(chainRun.statusSummary)")
                for line in chainRun.stepStatusLines {
                    lines.append(line)
                }
            } else {
                for step in chainSteps(for: chainID) {
                    lines.append("☑ \(step)")
                }
            }
        }

        lines.append("")
        lines.append("### 실행 모드")
        lines.append("- \(mode.rawValue)")

        lines.append("")
        lines.append("### 카드 결과")
        lines.append("유형: \(card.type.rawValue)")

        if !card.nextActionButtons.isEmpty {
            lines.append("")
            lines.append("### 다음 버튼")
            for button in card.nextActionButtons {
                lines.append("- \(button)")
            }
        }

        if !actionSuggestions.isEmpty {
            lines.append("")
            lines.append("### 제안 액션")
            for suggestion in actionSuggestions {
                let approval = suggestion.requiresApproval ? "승인 필요" : "바로 초안 가능"
                lines.append("- \(suggestion.title) [\(approval)]: \(suggestion.preview)")
            }
        }

        lines.append("")
        lines.append("### 검증 상태")
        lines.append("- 상태: \(verification.status)")
        if let failureCode = verification.failureCode {
            lines.append("- 사유: \(failureCode)")
        }
        lines.append("- \(verification.message)")

        if !evidence.promptContext.isEmpty {
            lines.append("")
            lines.append("### 확인한 근거")
            lines.append(String(evidence.promptContext.prefix(2_000)))
        } else if !attachments.isEmpty {
            lines.append("")
            lines.append("### 확인한 첨부")
            for attachment in attachments {
                let status = attachment.textContent?.isEmpty == false ? "텍스트 추출됨" : "텍스트 추출 없음"
                lines.append("- \(attachment.fileName): \(status)")
            }
        } else if mode == .readOnlyLookup {
            lines.append("")
            lines.append("### 대체 실행")
            lines.append("- 현재 사용 가능한 공개 조회 커넥터가 충분하지 않습니다.")
            lines.append("- 자료를 붙여주면 같은 카드 구조로 숫자·이슈·리스크를 분리해 이어서 처리합니다.")
        }

        lines.append("")
        lines.append("### 커넥터 상태")
        lines.append("- stockQuote: \(health.stockQuote.label)")
        lines.append("- newsSearch: \(health.newsSearch.label)")
        lines.append("- dartSearch: \(health.dartSearch.label)")
        lines.append("- calendarWrite: \(health.calendarWrite.label)")

        return lines.joined(separator: "\n")
    }

    private static func dedupeActionSuggestions(_ suggestions: [ActionSuggestion]) -> [ActionSuggestion] {
        var seen = Set<String>()
        var result: [ActionSuggestion] = []
        for suggestion in suggestions {
            if seen.insert(suggestion.type).inserted {
                result.append(suggestion)
            }
        }
        return result
    }

    private static func chainSteps(for chainID: SkillChainID) -> [String] {
        switch chainID {
        case .stockMoveAnalysis:
            return ["종목/질문 정규화", "시세 조회", "뉴스 근거 수집", "공시/시장 맥락 확인", "원인 후보 카드화"]
        case .mailAction:
            return ["메일 본문 읽기", "요청사항 추출", "날짜·시간 후보 추출", "답장/일정/할 일 제안"]
        case .documentAction:
            return ["첨부 텍스트 추출", "문서 유형 판단", "요약·숫자·날짜 추출", "체크리스트/문서화 제안"]
        case .tripPlanning:
            return ["출발/도착 조건 정리", "역·장소 후보 정리", "검색 조건 카드화", "일정 초안 제안"]
        case .accountReview:
            return ["거래 자료 읽기", "금액·날짜 정규화", "이상/중복 후보 표시", "증빙/정산 액션 제안"]
        case .research:
            return ["질문 정규화", "공개 출처 수집", "출처별 주장 분리", "확인 포인트 카드화"]
        }
    }

    private static func actionSuggestions(
        for intent: KSkillAssistIntent,
        evidence: ToolEvidenceResult,
        attachments: [ChatAttachment]
    ) -> [ActionSuggestion] {
        switch intent {
        case .mailSummaryAssist:
            return [
                ActionSuggestion(type: "calendar_draft", title: "캘린더 초안 만들기", preview: "메일에서 발견한 날짜·시간 후보를 일정 초안으로 정리합니다.", requiresApproval: true, handlerID: .calendarDraft),
                ActionSuggestion(type: "reply_draft", title: "답장 초안 만들기", preview: "요청사항과 마감 기준으로 답장 초안을 만듭니다.", handlerID: .replyDraft),
                ActionSuggestion(type: "todo_card", title: "할 일 카드로 저장", preview: "내가 해야 할 일을 이 방의 카드로 남깁니다.", handlerID: .todoCreate)
            ]
        case .fileImageAssist, .officeReviewAssist:
            return [
                ActionSuggestion(type: "deadline_extract", title: "마감·담당자 찾기", preview: "문서 안의 날짜, 담당, 제출물 후보를 뽑습니다.", handlerID: .summarizeArtifact),
                ActionSuggestion(type: "checklist", title: "체크리스트 만들기", preview: "문서 내용을 실행 항목으로 바꿉니다.", handlerID: .createDocument),
                ActionSuggestion(type: "document_artifact", title: "요약 문서 저장", preview: "카드 내용을 Markdown 문서로 저장합니다.", handlerID: .createDocument)
            ]
        case .stockInfoAssist:
            return [
                ActionSuggestion(type: "stock_memo", title: "투자 메모로 저장", preview: "시세·뉴스·공시 근거와 확인 포인트를 방 안에 남깁니다.", handlerID: .saveMemo),
                ActionSuggestion(type: "disclosure_followup", title: "공시 더 확인", preview: "최근 공시와 실적 관련 근거를 이어서 확인합니다.", handlerID: .summarizeArtifact)
            ]
        case .ktxBookingAssist, .mapPlaceAssist:
            return [
                ActionSuggestion(type: "copy_search_conditions", title: "검색 조건 복사", preview: "출발/도착/날짜 조건을 코레일·지도에 붙여넣기 좋게 정리합니다.", handlerID: .openBooking),
                ActionSuggestion(type: "calendar_draft", title: "일정 초안 만들기", preview: "이동 후보를 일정 초안으로 만듭니다.", requiresApproval: true, handlerID: .calendarDraft)
            ]
        case .accountReviewAssist:
            return [
                ActionSuggestion(type: "settlement_table", title: "정산표 만들기", preview: "거래내역을 금액·일자·증빙 상태로 정리합니다.", handlerID: .createDocument),
                ActionSuggestion(type: "evidence_mail", title: "증빙 요청 메일", preview: "누락 증빙을 요청하는 메일 초안을 만듭니다.", handlerID: .replyDraft)
            ]
        default:
            if evidence.sources.isEmpty && attachments.isEmpty { return [] }
            return [
                ActionSuggestion(type: "save_card", title: "카드 저장", preview: "확인한 내용을 방 안에 결과 카드로 남깁니다.", handlerID: .saveMemo)
            ]
        }
    }
}
