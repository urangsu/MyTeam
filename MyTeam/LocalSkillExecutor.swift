import Foundation

// MARK: - LocalSkillExecutionResult

enum LocalSkillExecutionResult {
    case handled(message: String, skillID: String)
    case needsInput(message: String, skillID: String)
    case notHandled
}

// MARK: - LocalSkillExecutor

enum LocalSkillExecutor {

    /// 활성화된 스킬 중 로컬에서 즉시 처리 가능한 스킬이 있으면 처리하고 결과를 반환한다.
    /// - 외부 API, LLM, ToolExecutor 호출 없음
    /// - 현재 지원: korean.character-count
    static func executeIfPossible(
        skills: [SkillManifest],
        userMessage: String
    ) -> LocalSkillExecutionResult {
        // korean.character-count
        if skills.contains(where: { $0.id == "korean.character-count" }) {
            if let targetText = KoreanTextMetricsService.extractTargetText(from: userMessage) {
                let metrics = KoreanTextMetricsService.analyze(targetText)
                let result = KoreanTextMetricsService.formatResult(metrics)
                return .handled(message: result, skillID: "korean.character-count")
            } else {
                // 본문이 없음 → 입력 요청
                let message = """
                계산할 텍스트를 함께 보내주세요.

                예: 글자 수 세줘: MyTeam은 macOS에서 팀원처럼 일하는 AI입니다.
                """
                return .needsInput(message: message, skillID: "korean.character-count")
            }
        }

        return .notHandled
    }
}
