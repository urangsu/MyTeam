import Foundation
import AppKit

// MARK: - ClipboardContextReader
// Round 243A-OBSERVE: 명시적 호출 전용 클립보드 읽기.
//
// 정책:
// - 상시 감시 / timer polling 하드 블록
// - 앱 시작 시 자동 읽기 금지
// - 사용자가 버튼을 누르거나 "클립보드 읽어줘"라고 말할 때만 실행
// - credential 패턴이면 blocked 반환
// - 원문 장기 저장 금지 (preview만 생성)

struct ClipboardContextPreview: Sendable {
    let truncatedText: String    // 최대 300자 미리보기
    let characterCount: Int
    let isBlocked: Bool          // credentialLike 감지
    let blockReason: String?
    let suggestedContentKind: ObservationContentKind
}

enum ClipboardContextReader {

    // MARK: - Hard Block Guard

    /// 타이머/폴링으로 자동 읽기: 절대 금지
    private static let continuousMonitoringAllowed = false   // compile-time constant

    // MARK: - Explicit Read

    /// 사용자 명시 요청 시 클립보드 읽기
    /// - Returns: preview (credentialLike이면 isBlocked = true)
    @MainActor
    static func readExplicit() -> ClipboardContextPreview {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return ClipboardContextPreview(
                truncatedText: "",
                characterCount: 0,
                isBlocked: false,
                blockReason: nil,
                suggestedContentKind: .text
            )
        }
        // Credential guard
        if ObservationPermissionPolicy.containsCredentialPattern(text) {
            AppLog.info("[ClipboardReader] blocked: credential-like content detected")
            return ClipboardContextPreview(
                truncatedText: "[BLOCKED]",
                characterCount: text.count,
                isBlocked: true,
                blockReason: "API key / token / password 패턴이 감지되어 클립보드 내용을 읽지 않습니다.",
                suggestedContentKind: .unknown
            )
        }
        let truncated = text.count > 300 ? String(text.prefix(300)) + "…" : text
        let kind = inferContentKind(from: text)
        return ClipboardContextPreview(
            truncatedText: truncated,
            characterCount: text.count,
            isBlocked: false,
            blockReason: nil,
            suggestedContentKind: kind
        )
    }

    /// 클립보드 텍스트를 LocalObservation으로 변환 (사용자 확인 요청)
    @MainActor
    static func readAsObservation(roomID: UUID? = nil) -> LocalObservation? {
        let preview = readExplicit()
        if preview.isBlocked { return nil }
        if preview.truncatedText.isEmpty { return nil }
        return LocalObservation(
            roomID: roomID,
            source: .clipboard,
            fileURL: nil,
            displayName: "클립보드 텍스트",
            contentKind: preview.suggestedContentKind,
            fileSizeBytes: Int64(preview.characterCount),
            userVisibleSummary: "클립보드에서 \(preview.characterCount)자 텍스트를 읽었어요."
        )
    }

    // MARK: - Content Kind Inference

    private static func inferContentKind(from text: String) -> ObservationContentKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") || trimmed.contains("\n## ") { return .markdown }
        // 표 패턴 (탭이나 콤마 구분, 여러 행)
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if lines.count > 2 && lines.first?.contains("\t") == true { return .spreadsheet }
        if lines.count > 2 && lines.first?.contains(",") == true { return .spreadsheet }
        return .text
    }
}
