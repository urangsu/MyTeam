import Foundation

enum ClarificationDecision: Equatable {
    case proceedWithAssumptions([String])
    case askRequired([String])
    case blocked(String)
}

enum ClarificationPolicy {
    static func decide(for goal: GoalInterpretation) -> ClarificationDecision {
        let routeDecision = CapabilityAwareRouter.evaluate(goal: goal)
        switch routeDecision.status {
        case .blocked:
            return .blocked(routeDecision.message)
        case .requiresApproval:
            return .proceedWithAssumptions([
                "필요한 부분은 초안 기준으로 진행합니다.",
                "민감한 작업은 별도 확인이 필요합니다."
            ])
        case .future:
            return .proceedWithAssumptions([
                "현재는 연결 준비 단계입니다.",
                "연결 후 실제 데이터를 반영할 수 있습니다."
            ])
        case .available, .unavailable:
            break
        }

        if !goal.missingInputs.isEmpty {
            switch goal.goalType {
            case .appLaunch, .privacyTerms, .connectorSetup:
                return .askRequired(goal.missingInputs)
            default:
                return .proceedWithAssumptions(goal.missingInputs)
            }
        }

        switch goal.goalType {
        case .mailAction:
            return .proceedWithAssumptions([
                "메일 초안은 작성하되, 발송은 별도 확인이 필요합니다."
            ])
        case .calendarAction:
            return .proceedWithAssumptions([
                "일정 생성 / 수정은 아직 연결 준비 단계입니다."
            ])
        default:
            return .proceedWithAssumptions([])
        }
    }

    static func decideForUniversalDocument(
        _ request: UniversalDocumentSkillRequest,
        context: RoomGoalContext? = nil
    ) -> ClarificationDecision {
        let sourceText = request.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sourceText.isEmpty {
            return .proceedWithAssumptions([
                "제공된 원문을 우선 반영합니다.",
                "부족한 부분은 작성 가정으로 보완합니다."
            ])
        }

        if let context,
           !context.recentArtifactIDs.isEmpty,
           GoalContextEngine.referencesRecentArtifact(request.userMessage) {
            return .proceedWithAssumptions([
                "직전에 만든 결과물을 이어서 반영합니다.",
                "부족한 부분은 작성 가정으로 보완합니다."
            ])
        }

        let hasDocumentContext = hasContextualDocumentSignal(request.userMessage)

        switch request.type {
        case .summary:
            if hasDocumentContext {
                return .proceedWithAssumptions([
                    "문맥을 기준으로 요약 초안을 작성합니다.",
                    "부족한 부분은 작성 가정으로 보완합니다."
                ])
            }
            return .askRequired(["정리할 원문이나 주제를 알려주시면 바로 문서로 만들어드릴게요."])
        case .meetingMinutes:
            if hasDocumentContext {
                return .proceedWithAssumptions([
                    "문맥을 기준으로 회의록 초안을 작성합니다.",
                    "부족한 부분은 작성 가정으로 보완합니다."
                ])
            }
            return .askRequired(["회의 메모나 대화 원문을 주시면 회의록으로 정리할게요."])
        case .tableSummary:
            if hasDocumentContext {
                return .proceedWithAssumptions([
                    "문맥을 기준으로 표 정리를 진행합니다.",
                    "부족한 부분은 작성 가정으로 보완합니다."
                ])
            }
            return .askRequired(["표로 정리할 원문이나 항목 목록을 보내주세요."])
        case .actionItems:
            if hasDocumentContext {
                return .proceedWithAssumptions([
                    "문맥을 기준으로 액션아이템 초안을 작성합니다.",
                    "부족한 부분은 작성 가정으로 보완합니다."
                ])
            }
            return .askRequired(["액션아이템으로 뽑을 회의 내용이나 원문을 보내주세요."])
        case .reportDraft:
            if request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || request.title == "문서" {
                return .askRequired(["보고서로 정리할 주제나 원문을 알려주세요."])
            }
            return .proceedWithAssumptions([
                "주제를 기준으로 보고서 초안을 작성합니다.",
                "부족한 배경은 작성 가정으로 보완합니다."
            ])
        case .checklist:
            if request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasDocumentContext {
                return .askRequired(["체크리스트로 만들 도메인이나 주제를 알려주세요."])
            }
            return .proceedWithAssumptions([
                "도메인을 기준으로 체크리스트 초안을 작성합니다.",
                "부족한 항목은 작성 가정으로 보완합니다."
            ])
        }
    }

    private static func hasContextualDocumentSignal(_ message: String) -> Bool {
        let lower = message.lowercased()
        let cues = [
            "문서", "업무용", "자료", "내용", "회의", "보고", "표",
            "체크리스트", "파일로", "붙여넣", "아래 내용", "원문", "초안"
        ]
        if cues.contains(where: { lower.contains($0) }) {
            return true
        }
        return message.contains("\n") || message.contains("```") || message.count >= 20
    }
}
