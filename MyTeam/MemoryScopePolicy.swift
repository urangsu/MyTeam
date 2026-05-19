import Foundation

// MARK: - MemoryScopePolicy
// Round 244A: 사용자 입력/결과에서 memory candidate의 scope/sensitivity를 분류한다.
// 규칙은 heuristic 기반. LLM 추출은 다음 라운드.

enum MemoryScopePolicy {

    // MARK: - Classification

    /// 텍스트 후보를 분석하여 scope + sensitivity 분류 반환
    static func classify(text: String) -> (scope: MemoryScope, sensitivity: MemorySensitivityClass)? {
        let lower = text.lowercased()

        // ── 저장 금지: credentialLike ──────────────────────────────
        if containsCredentialPattern(lower) {
            return (.turn, .credentialLike)   // scope=turn 은 "쓰지 말 것" 신호
        }

        // ── userProfile: 출력 스타일, 글투, 항상 선호 ──────────────
        if containsUserProfileSignal(lower) {
            return (.userProfile, .publicPreference)
        }

        // ── procedural: 반복 업무 방식, 절차, 포맷 ────────────────
        if containsProceduralSignal(lower) {
            return (.procedural, .workPreference)
        }

        // ── businessConfidential: 거래처/금액/계약 조건 ─────────────
        if containsBusinessConfidentialSignal(lower) {
            return (.room, .businessConfidential)
        }

        // ── personalSensitive: 개인정보, 의료, 법적 ─────────────────
        if containsPersonalSensitiveSignal(lower) {
            return (.room, .personalSensitive)
        }

        // ── domain: 특정 업무 도메인 기준 언급 ───────────────────────
        if containsDomainSignal(lower) {
            return (.domain, .workPreference)
        }

        // ── room: 일반적인 방 컨텍스트 ──────────────────────────────
        if text.count > 20 {
            return (.room, .publicPreference)
        }

        return nil
    }

    /// 이 candidate를 자동 저장할 수 있는지 판단
    static func canAutoStore(sensitivity: MemorySensitivityClass, scope: MemoryScope) -> Bool {
        if sensitivity.isStorageBlocked { return false }
        if sensitivity.requiresApproval { return false }
        // organization scope는 현재 미지원
        if scope == .organization { return false }
        return true
    }

    /// 승인이 필요한지 판단
    static func requiresApproval(sensitivity: MemorySensitivityClass) -> Bool {
        sensitivity.requiresApproval
    }

    // MARK: - Domain Detection

    static func detectDomain(from text: String) -> MemoryDomain {
        let lower = text.lowercased()
        if containsAny(lower, ["계정", "계정코드", "계정과목", "분개", "세금", "부가세", "결산", "회계", "재무"]) {
            return .accounting
        }
        if containsAny(lower, ["계약서", "법무", "갑을", "갑은", "을은", "약관", "소송", "권리", "의무"]) {
            return .legal
        }
        if containsAny(lower, ["블로그", "콘텐츠", "마케팅", "sns", "광고", "바이럴", "캠페인", "카피"]) {
            return .marketing
        }
        if containsAny(lower, ["일정", "마일스톤", "스프린트", "task", "태스크", "칸반", "pm", "roadmap"]) {
            return .projectManagement
        }
        if containsAny(lower, ["코드", "api", "버그", "배포", "서버", "데이터베이스", "스택", "swift", "python"]) {
            return .development
        }
        if containsAny(lower, ["앱스토어", "출시", "심사", "앱 이름", "스크린샷", "메타데이터"]) {
            return .appLaunch
        }
        return .general
    }

    // MARK: - Signal Detectors (private)

    private static func containsCredentialPattern(_ lower: String) -> Bool {
        let patterns = [
            "api key", "api키", "apikey", "token", "토큰",
            "password", "비밀번호", "passwd", "secret key",
            "access token", "refresh token", "private key",
            "client secret", "auth token", "bearer "
        ]
        return containsAny(lower, patterns)
    }

    private static func containsUserProfileSignal(_ lower: String) -> Bool {
        let patterns = [
            "항상", "앞으로도", "내 스타일", "내 글투", "내 취향",
            "나는 항상", "나는 보통", "내가 쓰는 방식",
            "모바일 가독성", "짧게 써", "표로 먼저",
            "기억해줘", "잊지 말고", "매번"
        ]
        return containsAny(lower, patterns)
    }

    private static func containsProceduralSignal(_ lower: String) -> Bool {
        let patterns = [
            "앞으로 보고서", "앞으로 문서", "검토할 때",
            "이런 순서로", "이렇게 정리해", "먼저 표로",
            "체크리스트 방식", "업무 절차", "반복 업무",
            "매번 이렇게", "이 방식으로", "다음번에도"
        ]
        return containsAny(lower, patterns)
    }

    private static func containsBusinessConfidentialSignal(_ lower: String) -> Bool {
        let patterns = [
            "거래처", "계약 금액", "단가", "매출", "수수료",
            "납품", "구매처", "공급가", "협력사",
            "계약서의 갑", "계약서의 을", "갑은 a사", "을은 b사",
            "이 프로젝트 예산"
        ]
        return containsAny(lower, patterns)
    }

    private static func containsPersonalSensitiveSignal(_ lower: String) -> Bool {
        let patterns = [
            "주민등록", "생년월일", "주소", "전화번호",
            "병원", "진단", "처방", "보험", "소득",
            "카드 번호", "계좌번호", "신용카드"
        ]
        return containsAny(lower, patterns)
    }

    private static func containsDomainSignal(_ lower: String) -> Bool {
        let patterns = [
            "계정과목", "계정코드", "블로그 포맷", "보고서 형식",
            "회계 기준", "법무 검토 기준", "앱스토어 기준"
        ]
        return containsAny(lower, patterns)
    }

    private static func containsAny(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }
}
