import Foundation

// MARK: - ObservationPermissionPolicy
// Round 243A-OBSERVE: observation source별 허용/제한 정책.
//
// 정책:
// - 자동 내용 분석은 사용자 확인 이후에만 가능
// - 상시 클립보드 감시, 상시 화면 캡처 하드 블록
// - Downloads 감시는 기본 OFF

enum ObservationPermissionPolicy {

    enum AutoDetectBehavior {
        /// 자동 감지 가능 (메타데이터만, 내용 분석은 확인 필요)
        case metadataOnly
        /// 사용자 명시 액션 필요
        case explicitActionRequired
        /// 현재 planned — 미구현 stub
        case planned
        /// 하드 블록
        case hardBlocked
    }

    // MARK: - Source 정책

    static func autoDetectBehavior(for source: ObservationSource) -> AutoDetectBehavior {
        switch source {
        case .chatAttachment:
            return .metadataOnly   // 첨부 즉시 감지 가능. 내용 분석은 사용자 요청 후.
        case .downloadsFolder:
            return .metadataOnly   // default OFF. 켜져 있을 때 파일명/크기/생성시각만 감지.
        case .clipboard:
            return .explicitActionRequired   // 상시 polling 하드 블록. 버튼/자연어 요청만.
        case .finderSelection:
            return .explicitActionRequired   // AppleScript/Accessibility 명시 요청만.
        case .screenSnapshot:
            return .planned        // planned. 단발성 명시 요청만. 상시 캡처 하드 블록.
        case .manualFileImport:
            return .metadataOnly   // 파일 패널 선택 후 즉시 감지.
        }
    }

    /// 이 source에 대해 내용 분석이 자동으로 가능한지
    static func canAutoAnalyzeContent(for source: ObservationSource) -> Bool {
        return false   // 모든 source에서 내용 분석은 사용자 확인 필요
    }

    /// 이 source가 현재 구현되어 있는지
    static func isImplemented(_ source: ObservationSource) -> Bool {
        switch source {
        case .chatAttachment, .downloadsFolder,
             .clipboard, .manualFileImport:    return true
        case .finderSelection:                 return true    // skeleton 구현
        case .screenSnapshot:                  return false   // planned only
        }
    }

    // MARK: - Hard Blocks

    /// 상시 클립보드 감시 여부 — 항상 false (하드 블록)
    static var continuousClipboardMonitoringAllowed: Bool { false }

    /// 상시 화면 캡처 여부 — 항상 false (하드 블록)
    static var continuousScreenCaptureAllowed: Bool { false }

    /// 자동 외부 업로드 허용 여부 — 항상 false (하드 블록)
    static var automaticExternalUploadAllowed: Bool { false }

    /// 자동 파일 삭제 허용 여부 — 항상 false
    static var automaticFileDeletionAllowed: Bool { false }

    // MARK: - Credential Guard

    /// 텍스트에서 credential 패턴 감지 (클립보드 읽기 시 사용)
    static func containsCredentialPattern(_ text: String) -> Bool {
        let lower = text.lowercased()
        let patterns = [
            "api key", "apikey", "api_key", "token", "토큰",
            "password", "비밀번호", "passwd", "secret",
            "access_token", "refresh_token", "private_key",
            "client_secret", "bearer ", "authorization:"
        ]
        return patterns.contains { lower.contains($0) }
    }

    // MARK: - Downloads Watcher Policy

    struct DownloadsWatcherPolicy {
        /// 기본값: OFF
        static let defaultEnabled = false
        /// 파일 내용 자동 분석: 금지
        static let autoContentAnalysis = false
        /// 사용자 확인 없이 room에 자동 attach: 금지
        static let autoAttachToRoom = false
        /// 지원 확장자 (메타데이터 감지만)
        static let monitoredExtensions: Set<String> = [
            "pdf", "csv", "xlsx", "xls", "docx", "pptx",
            "txt", "md", "png", "jpg", "jpeg", "heic", "zip"
        ]
        /// 감지 대상 최소 파일 크기 (1KB 이하 무시)
        static let minimumFileSizeBytes: Int64 = 1024
    }
}
