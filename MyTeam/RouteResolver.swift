import Foundation

struct RouteResolutionInput {
    let userMessage: String
    let enabledSkills: [SkillManifest]
    let disabledSkills: [SkillManifest]
    let goal: GoalInterpretation
    let capabilityDecision: CapabilityRouteDecision
}

enum RouteResolver {
    static var isAvailable: Bool { true }

    static func resolveInitialRoute(_ input: RouteResolutionInput) -> RouteDecision {
        if let blocked = GoalGate.blockedDecision(goal: input.goal, capability: input.capabilityDecision) {
            return blocked
        }

        switch input.capabilityDecision.status {
        case .future:
            return RouteDecision(
                kind: .capabilityFuture,
                reason: input.capabilityDecision.message,
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "future capability notice"
            )
        case .requiresApproval:
            return RouteDecision(
                kind: .capabilityRequiresApproval,
                reason: input.capabilityDecision.message,
                skillID: nil,
                requiresApproval: true,
                expectedOutput: "approval required notice"
            )
        case .unavailable:
            return RouteDecision(
                kind: .capabilityUnavailable,
                reason: input.capabilityDecision.message,
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "unavailable notice"
            )
        case .available, .blocked:
            break
        }

        if let disabledSkill = input.disabledSkills.first {
            return RouteDecision(
                kind: .disabledSkill,
                reason: "disabled skill matched: \(disabledSkill.id)",
                skillID: disabledSkill.id,
                requiresApproval: false,
                expectedOutput: "disable notice"
            )
        }

        if case .handled(_, let skillID) = LocalSkillExecutor.detectIfPossible(skills: input.enabledSkills, userMessage: input.userMessage) {
            return RouteDecision(
                kind: .localSkill,
                reason: "local skill handled: \(skillID)",
                skillID: skillID,
                requiresApproval: false,
                expectedOutput: "local skill result"
            )
        }

        if case .needsInput(_, let skillID) = LocalSkillExecutor.detectIfPossible(skills: input.enabledSkills, userMessage: input.userMessage) {
            return RouteDecision(
                kind: .localSkill,
                reason: "local skill needs input: \(skillID)",
                skillID: skillID,
                requiresApproval: false,
                expectedOutput: "input request"
            )
        }

        if let appLaunchType = AppLaunchSkillService.detectSkillType(from: input.userMessage) {
            return RouteDecision(
                kind: .appLaunch,
                reason: "app launch skill detected: \(appLaunchType.skillID)",
                skillID: appLaunchType.skillID,
                requiresApproval: false,
                expectedOutput: "markdown artifact"
            )
        }

        if input.goal.goalType == .privacyTerms || input.userMessage.lowercased().contains("개인정보처리방침") || input.userMessage.lowercased().contains("이용약관") {
            return RouteDecision(
                kind: .privacyTerms,
                reason: "privacy terms detected",
                skillID: "korean.privacy-terms",
                requiresApproval: false,
                expectedOutput: "privacy terms artifact"
            )
        }

        if let command = LocalSchedulerCommandDetector.detect(input.userMessage),
           LocalSchedulerDocumentBridge.targetType(for: command) != nil {
            return RouteDecision(
                kind: .localSchedulerDocumentBridge,
                reason: "local scheduler document bridge detected: \(command.kind.rawValue)",
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "scheduler document artifact"
            )
        }

        if let command = LocalSchedulerCommandDetector.detect(input.userMessage) {
            return RouteDecision(
                kind: .localSchedulerCommand,
                reason: "local scheduler command detected: \(command.kind.rawValue)",
                skillID: nil,
                requiresApproval: command.requiresApproval,
                expectedOutput: "scheduler summary or action"
            )
        }

        if input.goal.goalType == .dailyBriefing || input.goal.goalType == .calendarBriefing || input.goal.goalType == .mailBriefing {
            return RouteDecision(
                kind: .dailyBriefing,
                reason: "daily briefing goal detected",
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "briefing summary"
            )
        }

        if input.goal.goalType == .connectorSetup {
            return RouteDecision(
                kind: .directChat,
                reason: "briefing / connector route deferred",
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "direct answer"
            )
        }

        if let docType = UniversalDocumentSkillService.detectSkillType(from: input.userMessage) {
            return RouteDecision(
                kind: .universalDocument,
                reason: "universal document detected: \(docType.skillID)",
                skillID: docType.skillID,
                requiresApproval: false,
                expectedOutput: "markdown artifact"
            )
        }

        if looksLikeArtifactWorkflow(input.userMessage) {
            return RouteDecision(
                kind: .artifactWorkflow,
                reason: "file creation heuristic matched",
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "artifact file"
            )
        }

        if input.goal.goalType == .teamDiscussion {
            return RouteDecision(
                kind: .teamDiscussion,
                reason: "team discussion goal detected",
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "team discussion"
            )
        }

        if input.goal.goalType == .directAnswer || input.goal.goalType == .unknown {
            return RouteDecision(
                kind: .directChat,
                reason: "fallback direct chat",
                skillID: nil,
                requiresApproval: false,
                expectedOutput: "direct answer"
            )
        }

        return RouteDecision(
            kind: .fallback,
            reason: "no deterministic route",
            skillID: nil,
            requiresApproval: false,
            expectedOutput: "fallback"
        )
    }

    private static func looksLikeArtifactWorkflow(_ message: String) -> Bool {
        let lower = message.lowercased()
        let nouns = ["ppt", "피피티", "프레젠테이션", "발표자료", "엑셀", "스프레드시트", "파일", "markdown", "md", "artifact", "산출물"]
        let verbs = ["만들어", "작성해", "생성해", "저장해", "정리"]
        if nouns.contains(where: { lower.contains($0) }) && verbs.contains(where: { lower.contains($0) }) {
            return true
        }
        if (lower.contains("표로") || lower.contains("표를")) &&
            (lower.contains("정리") || lower.contains("만들") || lower.contains("작성") || lower.contains("생성")) {
            return true
        }
        return false
    }
}
