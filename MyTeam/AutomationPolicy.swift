import Foundation

// MARK: - AutomationPolicy
// 스케줄 태스크 실행 전 destructive action 차단 정책

enum AutomationPolicy {

    // MARK: - 차단 패턴

    /// 스케줄 업무에서 금지되는 명령/패턴
    private static let blockedPatterns: [(pattern: String, reason: String)] = [
        ("/open ",      "파일 시스템 직접 접근은 스케줄에서 허용되지 않습니다."),
        ("rm ",         "삭제 명령은 스케줄에서 허용되지 않습니다."),
        ("delete ",     "삭제 명령은 스케줄에서 허용되지 않습니다."),
        ("sudo ",       "권한 상승 명령은 스케줄에서 허용되지 않습니다."),
        ("curl ",       "외부 네트워크 직접 호출은 스케줄에서 허용되지 않습니다."),
        ("wget ",       "외부 네트워크 직접 호출은 스케줄에서 허용되지 않습니다."),
    ]

    // MARK: - 검증

    /// 스케줄 태스크 prompt가 실행 가능한지 검증
    /// - Returns: (allowed, reason) — 차단 시 reason에 사유 포함
    static func isAllowed(_ prompt: String) -> (allowed: Bool, reason: String?) {
        let lower = prompt.lowercased()
        for entry in blockedPatterns {
            if lower.contains(entry.pattern) {
                return (false, entry.reason)
            }
        }
        return (true, nil)
    }
}
