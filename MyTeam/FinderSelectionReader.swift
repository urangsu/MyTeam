import Foundation

// MARK: - FinderSelectionReader
// Round 243A-OBSERVE: Finder 선택 파일 명시적 읽기 (skeleton).
//
// 정책:
// - 명시적 사용자 요청 필요
// - 권한/샌드박스 실패 시 "파일을 끌어다 놓아 주세요" fallback
// - AppleScript / Accessibility 실제 구현은 Mac local build phase에서 완성
//
// TODO (Mac local):
// - NSAppleScript 또는 AXUIElement로 Finder selection 읽기
// - security-scoped URL bookmark 저장
// - entitlement: com.apple.security.automation.apple-events

enum FinderSelectionReaderError: LocalizedError {
    case notImplementedYet
    case accessibilityPermissionDenied
    case noFilesSelected
    case sandboxRestriction

    var errorDescription: String? {
        switch self {
        case .notImplementedYet:
            return "Finder 선택 읽기는 다음 업데이트에서 제공됩니다. 파일을 끌어다 놓아 주세요."
        case .accessibilityPermissionDenied:
            return "Finder 접근 권한이 필요합니다. 시스템 설정 → 개인 정보 보호 → 접근성에서 MyTeam을 허용해 주세요."
        case .noFilesSelected:
            return "Finder에서 파일을 선택한 후 다시 시도해 주세요."
        case .sandboxRestriction:
            return "파일을 끌어다 놓아 주세요."
        }
    }

    /// 사용자에게 보여줄 fallback 안내
    var fallbackGuidance: String {
        "파일을 채팅창에 끌어다 놓으면 바로 분석할 수 있어요."
    }
}

enum FinderSelectionReader {

    // MARK: - Public API

    /// Finder 선택 파일 읽기 (skeleton — Mac local에서 완성 예정)
    static func readCurrentFinderSelection() async throws -> [LocalObservation] {
        // TODO (Mac local): AppleScript / AXUIElement 구현
        // let script = NSAppleScript(source: finderSelectionScript)
        // let result = script?.executeAndReturnError(nil)
        // ...
        throw FinderSelectionReaderError.notImplementedYet
    }

    /// 권한 상태 확인 (future use)
    static func checkPermissionStatus() -> PermissionStatus {
        // TODO (Mac local): AXIsProcessTrustedWithOptions 확인
        return .unknown
    }

    enum PermissionStatus {
        case granted
        case denied
        case unknown
        case notRequired   // sandbox fallback
    }

    // MARK: - Fallback Message

    static var fallbackMessage: String {
        "파일을 채팅창에 끌어다 놓으면 바로 분석할 수 있어요."
    }

    // MARK: - AppleScript Template (future)

    // 실제 구현 시 사용할 AppleScript 템플릿
    // "tell application \"Finder\"\n  selection as alias list\nend tell"
}
