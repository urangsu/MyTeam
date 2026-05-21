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

// MARK: - Runtime

enum KSkillAssistRuntime {

    // MARK: - Detection

    static func detectIntent(userMessage: String, skillID: String? = nil) -> KSkillAssistIntent? {
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
            case "map-place-assist", "reservation-preparation": return .mapPlaceAssist
            default: break
            }
        }

        // Natural language detection
        if lower.contains("ktx") || lower.contains("srt") || lower.contains("기차 예매") || lower.contains("열차 예매") {
            return .ktxBookingAssist
        }
        if lower.contains("주가") || lower.contains("주식") || lower.contains("종목") || lower.contains("시세") {
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
                message: "지도 직접 검색은 아직 연결 전입니다. 장소명이나 링크를 주시면 비교 기준과 예약 전 체크리스트로 정리해드릴게요.",
                checklist: [
                    "방문 목적과 인원 확인",
                    "영업 시간 및 정기 휴무일 확인",
                    "예약 필수 여부 (전화/온라인/앱)",
                    "주차 가능 여부",
                    "위치·교통편 확인",
                    "취소·변경 정책 확인"
                ],
                nextActions: [
                    "네이버 지도 또는 카카오맵에서 직접 검색",
                    "장소명이나 링크를 주시면 비교 기준을 정리해드릴 수 있습니다"
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
                message: "실시간 시세 조회는 아직 연결 전입니다. 종목명과 자료를 주시면 확인할 지표와 리스크 체크리스트를 정리해드릴게요.",
                checklist: [
                    "종목 기본 정보 확인 (업종, 시가총액)",
                    "최근 실적 및 공시 확인 (DART)",
                    "PER / PBR / ROE 등 밸류에이션 지표",
                    "52주 고가/저가 대비 현재 위치",
                    "주요 리스크 요인 파악",
                    "배당 여부 및 배당수익률 확인"
                ],
                nextActions: [
                    "네이버 증권 또는 HTS에서 직접 시세 확인",
                    "공시 자료나 기사를 붙여주시면 요약해드릴 수 있습니다"
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
                message: "DART 직접 조회는 아직 연결 전입니다. 공시 PDF, 사업보고서 내용, 공시 링크를 주시면 요약 형식으로 정리해드릴 수 있어요.",
                checklist: [
                    "공시 종류 확인 (사업보고서/분기보고서/수시공시)",
                    "보고 기간 및 작성일 확인",
                    "주요 재무지표 (매출/영업이익/순이익)",
                    "주요 위험 요인 섹션",
                    "관계회사 및 특수관계인 거래",
                    "감사인 의견"
                ],
                nextActions: [
                    "dart.fss.or.kr에서 직접 공시 검색",
                    "공시 PDF나 내용을 붙여주시면 요약·분석 기준으로 정리해드릴 수 있습니다"
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
                message: "실시간 네이버 검색은 아직 연결 전입니다. 링크나 본문을 주시면 요약·비교로 정리해드릴게요.",
                checklist: [
                    "출처 및 보도 날짜 확인",
                    "핵심 사실과 주장 구분",
                    "복수 매체 교차 확인",
                    "인용 출처 확인",
                    "광고성/편향 여부 파악"
                ],
                nextActions: [
                    "네이버 뉴스에서 직접 검색",
                    "기사 링크나 본문을 붙여주시면 요약·정리해드릴 수 있습니다"
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
                message: "실시간 네이버 검색은 아직 연결 전입니다. 링크나 본문을 주시면 요약·블로그 초안으로 정리해드릴게요.",
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
                message: "직접 최신 조회는 아직 연결 전입니다. 공고문이나 링크를 주시면 자격조건·준비서류·주의사항을 정리해드릴게요.",
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
                message: "직접 최신 조회는 아직 연결 전입니다. 공고문이나 링크를 주시면 자격조건·준비서류·주의사항을 정리해드릴게요.",
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
                message: "파일을 이 방으로 끌어다 놓거나 텍스트를 붙여넣으시면 정리·요약·검토 기준을 잡아드릴게요.",
                checklist: [
                    "파일 형식 확인 (PDF/텍스트/이미지/스프레드시트)",
                    "파일 내 민감 정보 여부 확인",
                    "처리 목적 결정 (요약/검토/변환)"
                ],
                nextActions: [
                    "파일을 이 방에 드래그하거나 텍스트를 붙여넣어 주세요",
                    "처리 목적을 말씀해 주시면 빠르게 시작할 수 있습니다"
                ],
                hardBlockedActions: [
                    "파일 외부 업로드",
                    "자동 삭제"
                ],
                requiredUserInputs: ["파일 또는 텍스트", "처리 목적"]
            )
        }
    }

    // MARK: - Markdown Formatter

    static func formatMarkdown(_ response: KSkillAssistResponse) -> String {
        var lines: [String] = []
        lines.append("## \(response.title)")
        lines.append("")
        lines.append(response.message)

        if !response.checklist.isEmpty {
            lines.append("")
            lines.append("### 확인 체크리스트")
            for item in response.checklist {
                lines.append("- [ ] \(item)")
            }
        }

        if !response.requiredUserInputs.isEmpty {
            lines.append("")
            lines.append("### 필요한 정보")
            for input in response.requiredUserInputs {
                lines.append("- \(input)")
            }
        }

        if !response.nextActions.isEmpty {
            lines.append("")
            lines.append("### 다음 단계")
            for (idx, action) in response.nextActions.enumerated() {
                lines.append("\(idx + 1). \(action)")
            }
        }

        if !response.hardBlockedActions.isEmpty {
            lines.append("")
            lines.append("### 직접 대신하지 않는 항목")
            for action in response.hardBlockedActions {
                lines.append("- 🚫 \(action)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
