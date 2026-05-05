import Foundation

enum LocalSkillExecutionResult {
    case handled(message: String, skillID: String)
    case needsInput(message: String, skillID: String)
    case notHandled
}

enum LocalSkillExecutor {

    static func executeIfPossible(skills: [SkillManifest], userMessage: String) -> LocalSkillExecutionResult {
        if skills.contains(where: { $0.id == "korean.character-count" }) {
            if let targetText = KoreanTextMetricsService.extractTargetText(from: userMessage) {
                let metrics = KoreanTextMetricsService.analyze(targetText)
                let result = KoreanTextMetricsService.formatResult(metrics)
                return .handled(message: result, skillID: "korean.character-count")
            }

            return .needsInput(
                message: "계산할 텍스트를 함께 보내주세요. 예: 글자 수 세줘: 안녕하세요",
                skillID: "korean.character-count"
            )
        }

        return .notHandled
    }
}
