import Foundation

enum GoalContextEngine {
    static func referencesRecentArtifact(_ message: String) -> Bool {
        let lower = message.lowercased()
        let markers = [
            "이거",
            "방금",
            "그거",
            "아까",
            "위 내용",
            "방금 만든",
            "아까 만든 거",
            "그 파일",
            "만든 거",
            "바로 전",
            "직전에 만든",
            "최근 문서",
            "그 문서",
            "이 문서"
        ]
        return markers.contains { lower.contains($0) }
    }

    static func referencesRecentFile(_ message: String) -> Bool {
        let lower = message.lowercased()
        let markers = [
            "이 파일",
            "이 파일을",
            "방금 파일",
            "방금 읽은 파일",
            "읽은 파일",
            "최근 파일",
            "파일 요약",
            "파일 보고서",
            "파일 체크리스트",
            "파일 회의록",
            "파일 액션아이템",
            "파일 표",
            "파일 정리",
            "파일 내용",
            "첨부한 파일",
            "올린 파일",
            "파일을 바탕으로",
            "파일 바탕으로"
        ]
        return !isFileCreationRequest(message) && markers.contains { lower.contains($0) }
    }

    static func isFileCreationRequest(_ message: String) -> Bool {
        let lower = message.lowercased()
        let createMarkers = [
            "엑셀 파일 만들어",
            "ppt 파일 만들어",
            "피피티 파일 만들어",
            "파일 만들어줘",
            "파일 만들어",
            "파일 생성",
            "파일 작성",
            "파일을 만들어",
            "파일로 만들어"
        ]
        return createMarkers.contains { lower.contains($0) }
    }

    static func latestReferencedArtifactID(
        message: String,
        context: RoomGoalContext?
    ) -> UUID? {
        guard referencesRecentArtifact(message),
              let context,
              let latest = context.recentArtifactIDs.first
        else { return nil }
        return latest
    }

    static func documentTypeFromFileRequest(_ message: String) -> UniversalDocumentSkillType? {
        let lower = message.lowercased()

        if lower.contains("회의록") || lower.contains("회의 내용") {
            return .meetingMinutes
        }
        if lower.contains("액션아이템") || lower.contains("할 일") {
            return .actionItems
        }
        if lower.contains("체크리스트") {
            return .checklist
        }
        if lower.contains("표로") || lower.contains("표 정리") || lower.contains("표로 정리") {
            return .tableSummary
        }
        if lower.contains("보고서") || lower.contains("보고서로") || lower.contains("보고서 만들어") {
            return .reportDraft
        }
        if lower.contains("요약") || lower.contains("정리") {
            return .summary
        }
        return UniversalDocumentSkillService.detectSkillType(from: message)
    }

    static func documentTypeFromArtifactReuseRequest(_ message: String) -> UniversalDocumentSkillType? {
        let lower = message.lowercased()

        if lower.contains("표로 바꿔") || lower.contains("표로 정리") || lower.contains("표로 변환") {
            return .tableSummary
        }
        if lower.contains("체크리스트") || lower.contains("체크리스트로") {
            return .checklist
        }
        if lower.contains("회의록") || lower.contains("회의록으로") || lower.contains("회의록 형식") {
            return .meetingMinutes
        }
        if lower.contains("액션아이템") || lower.contains("액션 아이템") || lower.contains("뽑아줘") {
            return .actionItems
        }
        if lower.contains("보고서") || lower.contains("보고서로") || lower.contains("보고서로 바꿔") {
            return .reportDraft
        }
        if lower.contains("요약") || lower.contains("다듬어") || lower.contains("정리해줘") {
            return .summary
        }
        return UniversalDocumentSkillService.detectSkillType(from: message)
    }
}
