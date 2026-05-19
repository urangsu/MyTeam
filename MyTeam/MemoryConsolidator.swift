import Foundation

// MARK: - MemoryConsolidator
// Round 244A: 대화/작업 후 heuristic 기반으로 memory candidate를 생성한다.
// LLM extraction은 다음 라운드 — 현재는 keyword + pattern 기반.
//
// 금지:
// - 파일 원문/sourceText를 candidate content에 포함 금지
// - credentialLike candidate 생성 → isStorageBlocked = true로 표시만
// - 모든 메시지를 candidate로 만들기 금지 (필터링 필수)

enum MemoryConsolidator {

    // MARK: - Public API

    struct Input: Sendable {
        let roomID: UUID
        let agentID: String?
        let userMessage: String
        let assistantResult: String
        let artifactTitles: [String]   // 원문 금지, 제목만
        let skillID: String?
    }

    /// 메시지 쌍에서 memory candidate 목록을 추출한다.
    static func extractCandidates(from input: Input) -> [MemoryCandidate] {
        var candidates: [MemoryCandidate] = []

        // 1. 사용자 메시지에서 candidate 추출
        let userCandidates = analyzeUserMessage(input.userMessage, roomID: input.roomID)
        candidates.append(contentsOf: userCandidates)

        // 2. assistant 결과에서 절차 candidate 추출 (단, 원문 아님)
        if let proceduralHint = extractProceduralHint(
            from: input.assistantResult,
            skillID: input.skillID
        ) {
            candidates.append(proceduralHint)
        }

        // 3. credentialLike는 차단 표시만
        candidates = candidates.map { c in
            if c.suggestedSensitivity.isStorageBlocked { return c }
            return c
        }

        return candidates.filter { c in
            // confidence 임계값 미달 → 탈락
            c.confidence >= 0.6
            // 빈 content → 탈락
            && !c.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            // content 30자 미만 → 정보 부족
            && c.content.count >= 10
        }
    }

    // MARK: - User Message Analysis

    private static func analyzeUserMessage(_ message: String, roomID: UUID) -> [MemoryCandidate] {
        var candidates: [MemoryCandidate] = []
        guard let (scope, sensitivity) = MemoryScopePolicy.classify(text: message) else {
            return []
        }

        // credentialLike → 저장 금지 candidate 생성 (경고 목적)
        if sensitivity.isStorageBlocked {
            candidates.append(MemoryCandidate(
                suggestedScope: .turn,
                suggestedSensitivity: .credentialLike,
                title: "자격증명 유사 텍스트 (저장 금지)",
                content: "[BLOCKED: credential-like content detected]",
                sourceRoomID: roomID,
                reason: "API key/token/password 패턴 감지 — 저장 차단",
                confidence: 0.95
            ))
            return candidates
        }

        // room scope → 방 컨텍스트로만 제한 (승인 필요 항목 포함)
        if scope == .room {
            let truncated = truncateForMemory(message)
            candidates.append(MemoryCandidate(
                suggestedScope: .room,
                suggestedSensitivity: sensitivity,
                title: roomContextTitle(from: message),
                content: truncated,
                sourceRoomID: roomID,
                reason: "방 컨텍스트 정보로 분류",
                confidence: sensitivity.requiresApproval ? 0.7 : 0.65
            ))
            return candidates
        }

        // userProfile / procedural / domain
        let truncated = truncateForMemory(message)
        let title = scopeTitle(scope: scope, from: message)
        candidates.append(MemoryCandidate(
            suggestedScope: scope,
            suggestedSensitivity: sensitivity,
            title: title,
            content: truncated,
            sourceRoomID: roomID,
            reason: scopeReason(scope: scope),
            confidence: 0.75
        ))

        return candidates
    }

    // MARK: - Procedural Hint from Result

    private static func extractProceduralHint(
        from result: String,
        skillID: String?
    ) -> MemoryCandidate? {
        guard let skillID, !skillID.isEmpty else { return nil }
        // 스킬 결과에서 절차 hint는 skil ID만 기록 (원문 금지)
        let content = "스킬 '\(skillID)' 실행 완료. 다음번에도 같은 흐름 사용 가능."
        return MemoryCandidate(
            suggestedScope: .procedural,
            suggestedSensitivity: .workPreference,
            title: "스킬 실행 패턴: \(skillID)",
            content: content,
            reason: "반복 스킬 실행 → procedural memory 후보",
            confidence: 0.6
        )
    }

    // MARK: - Helpers

    /// 원문을 그대로 저장하지 않고 요약/잘라내기
    private static func truncateForMemory(_ text: String) -> String {
        let clean = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
        // 최대 120자 (원문 전체 저장 금지)
        return clean.count > 120 ? String(clean.prefix(120)) + "…" : clean
    }

    private static func scopeTitle(scope: MemoryScope, from text: String) -> String {
        let preview = String(text.prefix(30)).trimmingCharacters(in: .whitespacesAndNewlines)
        switch scope {
        case .userProfile:  return "선호: \(preview)"
        case .procedural:   return "업무 방식: \(preview)"
        case .domain:       return "도메인 기준: \(preview)"
        default:            return preview
        }
    }

    private static func roomContextTitle(from text: String) -> String {
        String(text.prefix(30)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func scopeReason(scope: MemoryScope) -> String {
        switch scope {
        case .userProfile:  return "사용자 선호/스타일 패턴 감지"
        case .procedural:   return "반복 업무 방식 언급 감지"
        case .domain:       return "도메인 기준 언급 감지"
        default:            return "자동 분류"
        }
    }
}
