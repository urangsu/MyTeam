import Foundation

// MARK: - ObservationPresentationPolicy
// Round 247A-OBSERVE: observation 관련 사용자 메시지 정책.
//
// 원칙:
// - 가능한 기능과 준비 중인 기능 명확히 구분
// - fake analysis 절대 금지
// - 다음 행동 제안 포함
// - full path 노출 금지
// - 원문 credential 절대 표시 금지

enum ObservationPresentationPolicy {

    /// 파일/텍스트가 방에 붙었을 때 메시지
    static func attachMessage(for observation: LocalObservation) -> String {
        let name = observation.displayName.isEmpty ? observation.contentKind.displayName : observation.displayName
        return "\(name)을(를) 이 방에 붙였어요. 자동 분석은 하지 않았습니다. 원하시면 \"요약해줘\", \"검토 기준을 먼저 잡아줘\"처럼 말씀해 주세요."
    }

    /// 사용자가 분석을 명시적으로 요청했을 때 준비 메시지
    static func analyzeMessage(for observation: LocalObservation) -> String {
        let name = observation.displayName.isEmpty ? observation.contentKind.displayName : observation.displayName
        return "이 파일을 이 방에 붙였어요. 자동 분석은 하지 않았습니다. 원하시면 요약/검토 기준을 먼저 잡아드릴게요."
    }

    /// 지원하지 않는 파일/소스에 대한 메시지
    static func unsupportedMessage(for observation: LocalObservation) -> String {
        "이 파일 형식(\(observation.contentKind.displayName))은 아직 지원 준비 중입니다. 텍스트, Markdown, CSV 파일을 먼저 지원합니다."
    }

    /// 준비 중인 기능에 대한 계획 메시지
    static func plannedMessage(for source: ObservationSource) -> String {
        switch source {
        case .screenSnapshot:
            return screenSnapshotPlannedMessage()
        case .finderSelection:
            return finderFallbackMessage()
        case .clipboard:
            return "클립보드 읽기는 명시적 요청 시에만 동작합니다."
        default:
            return "\(source.rawValue) 기능은 준비 중입니다."
        }
    }

    /// 클립보드 credential 차단 메시지
    static func clipboardBlockedMessage() -> String {
        "클립보드에서 비밀번호나 API 키처럼 보이는 내용이 감지되어 읽지 않았습니다. 민감하지 않은 텍스트를 복사 후 다시 시도해 주세요."
    }

    /// Finder 선택 파일 읽기 실패 fallback 메시지
    static func finderFallbackMessage() -> String {
        "권한 또는 환경 때문에 Finder 선택 파일을 읽지 못했습니다. 파일을 이 방으로 끌어다 놓아 주세요."
    }

    /// 화면 캡처 planned notice 메시지
    static func screenSnapshotPlannedMessage() -> String {
        "현재 화면 읽기는 단발성 권한 기반 기능으로 준비 중입니다. 상시 화면 감시는 하지 않습니다."
    }
}
