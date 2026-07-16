import XCTest
import AppKit
import PDFKit
import Security
@testable import MyTeam

// MARK: - LLMRouterTests
// Round 270C: Behavioral tests for LLM routing logic.
// Tests run against real code paths using @testable import;
// no network calls are made.

final class LLMRouterTests: XCTestCase {

    @MainActor
    func test_defaultTeamRoster_matchesReleaseCharacterGallery() {
        let defaultTeamAgentIDs = Set(AgentWindowManager.shared.activeAgents.map(\.id))
        let galleryAgentIDs = Set(
            CharacterCatalog.builtIn
                .filter { ProductSurfacePolicy.characterVisibilityInRelease($0.id) }
                .compactMap(\.agentID)
        )

        XCTAssertEqual(galleryAgentIDs, defaultTeamAgentIDs)
    }

    @MainActor
    func test_conversationReplyPolicy_distinguishesCasualWorkAndExplicitDetail() {
        XCTAssertEqual(ConversationReplyPolicy.mode(for: "안녕"), .quick)
        XCTAssertEqual(ConversationReplyPolicy.mode(for: "오늘 너무 힘들었어"), .casual)
        XCTAssertEqual(ConversationReplyPolicy.mode(for: "삼성전자 공시와 재무를 정리해줘"), .work)
        XCTAssertEqual(ConversationReplyPolicy.mode(for: "이 원리를 하나씩 자세히 설명해줘"), .explicitDetail)
    }

    func test_personalConversationLabels_useCorrectKoreanParticlesAndCompactDefaults() {
        XCTAssertEqual(KoreanText.conversationTitle(with: "루나"), "루나와의 대화")
        XCTAssertEqual(KoreanText.conversationTitle(with: "핀"), "핀과의 대화")
        XCTAssertEqual(
            KoreanText.personalRoomDisplayName(roomName: "루나과의 대화", agentName: "루나"),
            "기본 대화"
        )
        XCTAssertEqual(
            KoreanText.personalRoomDisplayName(roomName: "루나 대화 1", agentName: "루나"),
            "기본 대화"
        )
        XCTAssertEqual(
            KoreanText.personalRoomDisplayName(roomName: "캠페인 아이디어", agentName: "루나"),
            "캠페인 아이디어"
        )
    }

    func test_runtimeNeverPromotesDiscoveredModelsWithoutSmokeEvidence() {
        XCTAssertFalse(AIModelPolicy.dynamicModelDiscoveryAllowed)
        XCTAssertFalse(AIModelPolicy.modelOverrideAllowed)
    }

    func test_casualPersonalPolicy_doesNotInjectProfessionalRole() {
        let luna = AgentWindowManager.AgentConfig(
            id: "agent_2",
            name: "루나",
            role: "마케터/콘텐츠 기획",
            emoji: "🐰",
            color: .pink,
            isPremium: false,
            status: "준비",
            spriteName: nil,
            fallbackImageName: "루나_profile",
            dragEmoji: "😆",
            dragRotation: 10,
            dragSoundName: "Blow",
            dropSoundName: "Pop"
        )
        let toolPolicy = ToolPolicy.evaluate("안녕")

        let casualPolicy = ConversationMemory.buildPersonalResponsePolicy(
            for: luna,
            toolPolicy: toolPolicy,
            replyMode: .quick
        )
        XCTAssertFalse(casualPolicy.contains("마케터"))
        XCTAssertFalse(casualPolicy.contains("마케팅 전략"))
        XCTAssertTrue(casualPolicy.contains("후속 질문을 붙이지 마세요"))

        let workPolicy = ConversationMemory.buildPersonalResponsePolicy(
            for: luna,
            toolPolicy: toolPolicy,
            replyMode: .work
        )
        XCTAssertTrue(workPolicy.contains("마케터"))
        XCTAssertTrue(workPolicy.contains("마케팅 전략"))
    }

    func test_aiErrorPresentation_returnsActionableMessageWithoutRawRequestDetails() {
        let timeout = AIErrorPresentation.userMessage(for: URLError(.timedOut))
        XCTAssertTrue(timeout.contains("시간이 초과"))
        XCTAssertFalse(timeout.contains("https://"))

        let unavailableModel = AIErrorPresentation.userMessage(
            for: AIServiceError.httpError(404, "https://example.test?key=secret")
        )
        XCTAssertTrue(unavailableModel.contains("모델"))
        XCTAssertFalse(unavailableModel.contains("secret"))
    }

    func test_casualBubbleSegmenter_preservesContentWithinThreeParagraphs() {
        let original = "그랬구나. 오늘은 정말 힘들었겠다. 우선 숨부터 천천히 쉬어봐. 물도 한 잔 마시고. 내가 옆에서 같이 정리해볼게."
        let segments = CasualBubbleSegmenter.segments(from: original, mode: .casual)

        XCTAssertLessThanOrEqual(segments.count, 3)
        XCTAssertTrue(segments.allSatisfy { !$0.contains("\n") })
        XCTAssertEqual(
            CasualBubbleSegmenter.normalizedForComparison(segments.joined(separator: " ")),
            CasualBubbleSegmenter.normalizedForComparison(original)
        )
        XCTAssertTrue(segments.last?.contains("같이 정리해볼게") == true)
    }

    func test_casualBubbleSegmenter_doesNotBreakURLDateOrDecimal() {
        let original = "링크는 https://example.com/a.b?x=1.2 이야. 날짜는 2026.07.14이고 값은 3.14야. 확인해볼게."
        let segments = CasualBubbleSegmenter.segments(from: original, mode: .casual)

        XCTAssertTrue(segments.contains { $0.contains("https://example.com/a.b?x=1.2") })
        XCTAssertTrue(segments.contains { $0.contains("2026.07.14") })
        XCTAssertTrue(segments.contains { $0.contains("3.14") })
        XCTAssertEqual(
            CasualBubbleSegmenter.normalizedForComparison(segments.joined(separator: " ")),
            CasualBubbleSegmenter.normalizedForComparison(original)
        )
    }

    func test_streamingSentenceBoundary_keepsIncompleteTailForNextUtterance() {
        let first = ConversationSentenceBoundary.splitStreaming(
            "아 정말? 시우 덕분에 루나도 잠시"
        )
        XCTAssertEqual(first.completed, ["아 정말?"])
        XCTAssertEqual(first.remainder, " 시우 덕분에 루나도 잠시")

        let completed = ConversationSentenceBoundary.splitStreaming(
            first.remainder + " 쉬어가네! 다음 이야기도 궁금해."
        )
        XCTAssertEqual(
            completed.completed,
            ["시우 덕분에 루나도 잠시 쉬어가네!"]
        )
        XCTAssertEqual(completed.remainder, " 다음 이야기도 궁금해.")
    }

    func test_streamingSentenceBoundary_keepsEllipsisWithItsSentence() {
        let split = ConversationSentenceBoundary.splitStreaming("잠깐만... 이제 괜찮아!")
        XCTAssertEqual(split.completed, ["잠깐만..."])
        XCTAssertEqual(split.remainder, " 이제 괜찮아!")
    }

    func test_streamingSentenceBoundary_preservesWhitespaceAcrossTokens() {
        let first = ConversationSentenceBoundary.splitStreaming("오늘은 ")
        XCTAssertEqual(first.completed, [])
        XCTAssertEqual(first.remainder, "오늘은 ")

        let second = ConversationSentenceBoundary.splitStreaming(first.remainder + "좋아요.")
        XCTAssertEqual(second.completed, [])
        XCTAssertEqual(second.remainder, "오늘은 좋아요.")
    }

    func test_streamingSentenceBoundary_waitsForClosingQuoteLookahead() {
        let first = ConversationSentenceBoundary.splitStreaming("정말?")
        XCTAssertEqual(first.completed, [])
        XCTAssertEqual(first.remainder, "정말?")

        let second = ConversationSentenceBoundary.splitStreaming(first.remainder + "” 다음 문장.")
        XCTAssertEqual(second.completed, ["정말?”"])
        XCTAssertEqual(second.remainder, " 다음 문장.")
    }

    func test_streamingSentenceBoundary_handlesNumberedSentenceAndEmail() {
        let numbered = ConversationSentenceBoundary.splitStreaming("총 3. 다음 문장.")
        XCTAssertEqual(numbered.completed, ["총 3."])
        XCTAssertEqual(numbered.remainder, " 다음 문장.")

        let email = ConversationSentenceBoundary.splitStreaming("문의는 help@example.com으로 보내세요. 다음 안내입니다.")
        XCTAssertEqual(email.completed, ["문의는 help@example.com으로 보내세요."])
        XCTAssertEqual(email.remainder, " 다음 안내입니다.")
    }

    func test_casualConversationSanitizer_removesMarkdownEmphasisWithoutChangingWords() {
        XCTAssertEqual(
            ConversationTextSanitizer.sanitize("아, **정말** 고마워!", mode: .casual),
            "아, 정말 고마워!"
        )
        XCTAssertEqual(
            ConversationTextSanitizer.sanitize("__천천히__ 해도 괜찮아.", mode: .quick),
            "천천히 해도 괜찮아."
        )
        XCTAssertEqual(
            ConversationTextSanitizer.sanitize("2 * 3 = 6이고 *.swift 파일을 봐줘.", mode: .casual),
            "2 * 3 = 6이고 *.swift 파일을 봐줘."
        )
    }

    func test_casualTypingPolicy_matchesSixHundredStrokesPerMinute() {
        XCTAssertEqual(ChatTypingPolicy.strokesPerMinute, 600)
        XCTAssertEqual(ChatTypingPolicy.normalCharactersPerSecond, 5, accuracy: 0.001)
        XCTAssertEqual(
            ChatTypingPolicy.estimatedTypingDurationNanoseconds(for: "1234567890"),
            2_000_000_000
        )
    }

    func test_casualBubbleSegmentation_alignsWithTypewriterLimit() {
        let longSentence = String(repeating: "가", count: 101)
        let segments = CasualBubbleSegmenter.segments(from: longSentence, mode: .casual)

        XCTAssertGreaterThan(segments.count, 1)
        XCTAssertTrue(segments.allSatisfy { $0.count <= ChatTypingPolicy.maxAnimatedCharacters })
        XCTAssertTrue(
            segments.allSatisfy {
                ChatTypingPolicy.shouldAnimate(text: $0, isUser: false)
            }
        )
    }

    func test_casualBubbleSegmenter_keepsWorkAndExplicitDetailTogether() {
        let text = "첫 번째 설명입니다. 두 번째 설명입니다. 세 번째 설명입니다."

        XCTAssertEqual(CasualBubbleSegmenter.segments(from: text, mode: .work), [text])
        XCTAssertEqual(CasualBubbleSegmenter.segments(from: text, mode: .explicitDetail), [text])
    }

    func test_resultVerifier_treatsFormatLengthAsWarning() {
        let summary = ResultVerifier.verifySummary(content: "핵심만 짧게 정리했습니다.")
        let report = ResultVerifier.verifyReportDraft(content: "결론부터 공유합니다. 일정은 다음 주입니다.")
        let checklist = ResultVerifier.verifyChecklist(content: "- 첫 항목")
        let minutes = ResultVerifier.verifyMeetingMinutes(content: "오늘 회의에서는 출시 일정을 논의했습니다.")

        XCTAssertTrue(summary.passed)
        XCTAssertTrue(report.passed)
        XCTAssertTrue(checklist.passed)
        XCTAssertTrue(minutes.passed)
        XCTAssertGreaterThan(summary.warningCount, 0)
        XCTAssertGreaterThan(report.warningCount, 0)
        XCTAssertGreaterThan(checklist.warningCount, 0)
        XCTAssertGreaterThan(minutes.warningCount, 0)
    }

    func test_toolManifestCandidates_areRelevantAndBounded() {
        let candidates = ToolSemanticManifestCatalog.manifests(
            for: "삼성전자 뉴스와 공시를 확인해줘"
        )
        let toolIDs = Set(candidates.map(\.toolID))

        XCTAssertLessThanOrEqual(candidates.count, 5)
        XCTAssertTrue(toolIDs.contains("news.search"))
        XCTAssertTrue(toolIDs.contains("dart.disclosures.search"))
        XCTAssertFalse(toolIDs.contains("weather.current"))
        XCTAssertFalse(toolIDs.contains("calendar.events.today"))
    }

    func test_toolManifestCandidates_skipCasualConversation() {
        XCTAssertTrue(
            ToolSemanticManifestCatalog.manifests(for: "오늘 점심 뭐 먹을까?").isEmpty
        )
    }

    @MainActor
    func test_executionTracePreservesActualProviderModelAndFallback() async throws {
        let requestID = UUID()
        let metadata = LLMResponseMetadata(
            provider: .openAI,
            modelID: "gpt-4.1",
            fallbackChain: [.gemini, .openAI],
            usedFallback: true
        )

        await LLMExecutionTraceStore.shared.record(requestID: requestID, metadata: metadata)
        let recorded = await LLMExecutionTraceStore.shared.metadata(for: requestID)
        let stored = try XCTUnwrap(recorded)

        XCTAssertEqual(stored.provider, .openAI)
        XCTAssertEqual(stored.modelID, "gpt-4.1")
        XCTAssertEqual(stored.fallbackChain, [.gemini, .openAI])
        XCTAssertTrue(stored.usedFallback)
    }

    @MainActor
    func test_chatLogDecodesWithoutNewLLMMetadata() throws {
        let data = Data("""
        {
          "id":"00000000-0000-0000-0000-000000000001",
          "agentID":"agent_1",
          "agentName":"레오",
          "text":"기존 메시지",
          "isUser":false,
          "timestamp":0,
          "isSystem":false,
          "attachments":[],
          "sources":[],
          "artifactIDs":[]
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(AgentWindowManager.ChatLog.self, from: data)

        XCTAssertNil(decoded.llmProvider)
        XCTAssertNil(decoded.llmModelID)
        XCTAssertNil(decoded.llmFallbackUsed)
    }

    func test_openAIResponsesPolicy_onlyRoutesGPT56Family() {
        XCTAssertTrue(OpenAIResponsesAdapter.supports(modelID: "gpt-5.6"))
        XCTAssertTrue(OpenAIResponsesAdapter.supports(modelID: "gpt-5.6-sol"))
        XCTAssertTrue(OpenAIResponsesAdapter.supports(modelID: "gpt-5.6-terra"))
        XCTAssertTrue(OpenAIResponsesAdapter.supports(modelID: "gpt-5.6-luna"))
        XCTAssertFalse(OpenAIResponsesAdapter.supports(modelID: "gpt-4.1"))
        XCTAssertFalse(OpenAIResponsesAdapter.supports(modelID: "gpt-5.6-preview-copy"))
    }

    func test_openAIResponsesRequest_isStatelessAndUsesResponsesContract() throws {
        let request = try OpenAIResponsesAdapter.makeRequest(
            apiKey: "sk-test",
            modelID: "gpt-5.6-terra",
            messages: [["role": "user", "content": "hello"]],
            instructions: "Be concise.",
            maxOutputTokens: 256,
            stream: true,
            reasoningEffort: "low",
            safetyIdentifier: "myteam_test"
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        let body = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(body["model"] as? String, "gpt-5.6-terra")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertEqual(body["max_output_tokens"] as? Int, 256)
        XCTAssertEqual(body["safety_identifier"] as? String, "myteam_test")
        XCTAssertNil(body["previous_response_id"])
        XCTAssertNil(body["max_tokens"])
        XCTAssertNil(body["messages"])
    }

    @MainActor
    func test_openAIResponsesEvents_preserveTerminalState() throws {
        XCTAssertEqual(
            try OpenAIResponsesAdapter.parseEvent(#"{"type":"response.output_text.delta","delta":"안녕"}"#),
            .text("안녕")
        )
        XCTAssertEqual(
            try OpenAIResponsesAdapter.parseEvent(#"{"type":"response.completed","response":{"status":"completed"}}"#),
            .completed
        )
        XCTAssertEqual(
            try OpenAIResponsesAdapter.parseEvent(#"{"type":"response.incomplete","response":{"incomplete_details":{"reason":"max_output_tokens"}}}"#),
            .incomplete("max_output_tokens")
        )
        XCTAssertEqual(
            try OpenAIResponsesAdapter.parseEvent(#"{"type":"response.failed","response":{"error":{"message":"provider failed"}}}"#),
            .failed("provider failed")
        )
        XCTAssertEqual(
            try OpenAIResponsesAdapter.parseEvent(#"{"type":"error","message":"bad request"}"#),
            .failed("bad request")
        )
    }

    func test_openAIResponsesOutput_rejectsEmptyResponse() throws {
        let data = Data(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#.utf8)
        XCTAssertEqual(try OpenAIResponsesAdapter.outputText(from: data), "OK")

        let empty = Data(#"{"output":[]}"#.utf8)
        XCTAssertThrowsError(try OpenAIResponsesAdapter.outputText(from: empty))
    }

    func test_readinessEndpoints_matchRuntimeContract() {
        XCTAssertEqual(
            AIService.readinessEndpoint(for: .openAI, modelID: "gpt-4.1"),
            "https://api.openai.com/v1/chat/completions"
        )
        XCTAssertEqual(
            AIService.readinessEndpoint(for: .openAI, modelID: "gpt-5.6"),
            "https://api.openai.com/v1/responses"
        )
        XCTAssertEqual(
            AIService.readinessEndpoint(for: .openAI, modelID: "gpt-5.6-terra"),
            "https://api.openai.com/v1/responses"
        )
        XCTAssertEqual(
            AIService.readinessEndpoint(for: .claude, modelID: "claude-sonnet-4-5-20250514"),
            "https://api.anthropic.com/v1/messages"
        )
    }

    func test_readinessFailures_mapToProductCredentialFailures() {
        XCTAssertEqual(LLMReadinessFailure.invalidCredential.connectorFailureCode, .invalidAPIKey)
        XCTAssertEqual(LLMReadinessFailure.modelNotAccessible.connectorFailureCode, .permissionDenied)
        XCTAssertEqual(LLMReadinessFailure.rateLimited.connectorFailureCode, .rateLimited)
        XCTAssertEqual(LLMReadinessFailure.emptyGeneration.connectorFailureCode, .responseParseFailed)
    }

    func test_readinessCacheFingerprint_neverContainsRawKey() {
        let rawKey = "sk-test-secret-value"
        let fingerprint = LLMReadinessCache.keyFingerprint(for: rawKey)
        XCTAssertFalse(fingerprint.contains(rawKey))
        XCTAssertEqual(fingerprint.count, 24)
        XCTAssertEqual(fingerprint, LLMReadinessCache.keyFingerprint(for: rawKey))
        XCTAssertNotEqual(fingerprint, LLMReadinessCache.keyFingerprint(for: rawKey + "-changed"))
    }

    // MARK: - Test 1: 최신 모델이 차단되지 않음

    func test_latestModels_notBlocked() {
        // 현재 최신 모델들이 knownBrokenModels에 없어야 함
        XCTAssertFalse(LLMModelRegistry.isKnownBroken("gpt-4.1"),
                       "gpt-4.1은 차단 목록에 없어야 함")
        XCTAssertFalse(LLMModelRegistry.isKnownBroken("claude-sonnet-4-5-20250514"),
                       "claude-sonnet-4-5-20250514는 차단 목록에 없어야 함")
        XCTAssertFalse(LLMModelRegistry.isKnownBroken("gemini-2.5-flash"),
                       "gemini-2.5-flash는 차단 목록에 없어야 함")
        XCTAssertFalse(LLMModelRegistry.isKnownBroken("gemini-2.5-pro-preview-05-06"),
                       "gemini-2.5-pro-preview-05-06는 차단 목록에 없어야 함")
    }

    // MARK: - Test 2: fallback is explicit and fail-closed

    func test_providerCandidates_doNotCrossProvidersWhenFallbackDisabled() {
        let service = AIService.shared
        let normal = service.providerCandidates(
            preferred: .gemini,
            requiresToolUse: false,
            fallbackPolicy: .disabled,
            availableProvidersOverride: [.gemini]
        )
        XCTAssertTrue(normal.isEmpty || normal == [.gemini])
        XCTAssertFalse(normal.contains(.openAI))
        XCTAssertFalse(normal.contains(.claude))
        XCTAssertFalse(normal.contains(.openRouter))

        let unsupportedToolUse = service.providerCandidates(
            preferred: .gemini,
            requiresToolUse: true,
            fallbackPolicy: .disabled,
            availableProvidersOverride: [.gemini]
        )
        XCTAssertTrue(unsupportedToolUse.isEmpty)
    }

    func test_toolNeedClassifier_usesUserTextNotGroundedContext() {
        XCTAssertFalse(
            RoutingIntentPrecheck.needsTool("오늘 회의록 정리해줘"),
            "일반 문서 요청은 도구 라우팅으로 과잉 분류하면 안 됨"
        )
        XCTAssertTrue(
            RoutingIntentPrecheck.needsTool("웹에서 최신 자료 찾아서 정리해줘"),
            "명시적 웹/검색 요청은 tool-capable provider 후보를 우선해야 함"
        )
        XCTAssertTrue(
            RoutingIntentPrecheck.needsTool("첨부한 내용 요약해줘", hasAttachments: true),
            "첨부가 있으면 파일/자료 처리 능력이 있는 경로를 우선해야 함"
        )
    }

    // MARK: - Test 3: ResolvedLLMCall displayDescription 정확성

    func test_resolvedLLMCall_displayDescription() {
        // cached source
        let cached = ResolvedLLMCall(
            provider: .claude,
            modelID: "claude-sonnet-4-5-20250514",
            source: .cached("claude-sonnet-4-5-20250514")
        )
        XCTAssertTrue(cached.displayDescription.contains("cached"),
                      "cached source는 'cached' 문자를 포함해야 함")

        // discovered source
        let discovered = ResolvedLLMCall(
            provider: .gemini,
            modelID: "gemini-2.5-flash",
            source: .discovered("gemini-2.5-flash")
        )
        XCTAssertTrue(discovered.displayDescription.contains("live"),
                      "discovered source는 'live' 문자를 포함해야 함")

        // floor (pinned) source
        let floor = ResolvedLLMCall(
            provider: .openAI,
            modelID: "gpt-4.1",
            source: .floor("gpt-4.1")
        )
        XCTAssertTrue(floor.displayDescription.contains("pinned"),
                      "floor source는 'pinned' 문자를 포함해야 함")
    }

    // MARK: - Test 4: Room context isolation via RoomContext struct

    func test_roomContext_notCrossContaminated() {
        let roomAID = UUID()
        let roomBID = UUID()

        let msgA = AgentWindowManager.ChatLog(
            id: UUID(), agentID: "user", agentName: "수석님",
            text: "Room A 메시지", isUser: true, timestamp: Date()
        )
        let msgB = AgentWindowManager.ChatLog(
            id: UUID(), agentID: "user", agentName: "수석님",
            text: "Room B 메시지", isUser: true, timestamp: Date()
        )

        // 두 RoomContext를 직접 생성 — cross-room 오염 테스트
        let ctxA = RoomContext(
            roomID: roomAID,
            roomPurpose: "Room A",
            recentMessages: [msgA],
            recentArtifactSummaries: []
        )
        let ctxB = RoomContext(
            roomID: roomBID,
            roomPurpose: "Room B",
            recentMessages: [msgB],
            recentArtifactSummaries: []
        )

        // roomID 격리 확인
        XCTAssertEqual(ctxA.roomID, roomAID)
        XCTAssertEqual(ctxB.roomID, roomBID)
        XCTAssertNotEqual(ctxA.roomID, ctxB.roomID)

        // room A 메시지가 room B context에 없음
        let roomATexts = ctxA.recentMessages.map { $0.text }
        let roomBTexts = ctxB.recentMessages.map { $0.text }
        XCTAssertFalse(roomBTexts.contains(where: { roomATexts.contains($0) }),
                       "Room A 메시지가 Room B context에 포함되면 안 됨")

        // 각 room context에 올바른 메시지가 포함됨
        XCTAssertTrue(roomATexts.contains("Room A 메시지"))
        XCTAssertTrue(roomBTexts.contains("Room B 메시지"))
        XCTAssertFalse(roomATexts.contains("Room B 메시지"))
        XCTAssertFalse(roomBTexts.contains("Room A 메시지"))
    }

    @MainActor
    func test_roomContextBuilder_readsActualRoomOnly() {
        let manager = AgentWindowManager.shared
        let oldRooms = manager.rooms
        let oldCurrentRoomID = manager.currentRoomID
        let oldArtifacts = manager.recentArtifacts
        defer {
            manager.rooms = oldRooms
            manager.currentRoomID = oldCurrentRoomID
            manager.recentArtifacts = oldArtifacts
        }

        let roomAID = UUID()
        let roomBID = UUID()
        let roomAMessage = AgentWindowManager.ChatLog(
            id: UUID(), agentID: "user", agentName: "수석님",
            text: "Room A 실제 대화", isUser: true, timestamp: Date()
        )
        let roomBMessage = AgentWindowManager.ChatLog(
            id: UUID(), agentID: "user", agentName: "수석님",
            text: "Room B 실제 대화", isUser: true, timestamp: Date()
        )
        let systemMessage = AgentWindowManager.ChatLog(
            id: UUID(), agentID: "system", agentName: "시스템",
            text: "내부 진행 메시지", isUser: false, timestamp: Date(), isSystem: true
        )
        manager.rooms = [
            AgentWindowManager.ChatRoom(
                id: roomAID,
                name: "Room A",
                messages: [systemMessage, roomAMessage],
                agentIDs: ["team_all"],
                createdAt: Date()
            ),
            AgentWindowManager.ChatRoom(
                id: roomBID,
                name: "Room B",
                messages: [roomBMessage],
                agentIDs: ["team_all"],
                createdAt: Date()
            )
        ]

        let ctx = RoomContextBuilder.build(manager: manager, roomID: roomAID)
        let texts = ctx.contextualChatHistory.map(\.text)
        XCTAssertTrue(texts.contains("Room A 실제 대화"))
        XCTAssertFalse(texts.contains("Room B 실제 대화"))
        XCTAssertFalse(texts.contains("내부 진행 메시지"))
    }

    @MainActor
    func test_recentArtifacts_requiresRoomIDMatchWithoutGlobalFallback() {
        let manager = AgentWindowManager.shared
        let oldRooms = manager.rooms
        let oldCurrentRoomID = manager.currentRoomID
        let oldArtifacts = manager.recentArtifacts
        defer {
            manager.rooms = oldRooms
            manager.currentRoomID = oldCurrentRoomID
            manager.recentArtifacts = oldArtifacts
        }

        let roomAID = UUID()
        let roomBID = UUID()
        manager.rooms = [
            AgentWindowManager.ChatRoom(id: roomAID, name: "Room A", messages: [], agentIDs: ["team_all"], createdAt: Date()),
            AgentWindowManager.ChatRoom(id: roomBID, name: "Room B", messages: [], agentIDs: ["team_all"], createdAt: Date())
        ]
        manager.currentRoomID = roomAID
        manager.recentArtifacts = [
            IndexedArtifact(
                id: "a",
                workflowID: "wf-a",
                title: "A 문서",
                type: .text,
                filename: "a.md",
                relativePath: "a.md",
                preview: "",
                createdAt: "now",
                roomID: roomAID.uuidString
            ),
            IndexedArtifact(
                id: "legacy",
                workflowID: "wf-legacy",
                title: "전역 레거시",
                type: .text,
                filename: "legacy.md",
                relativePath: "legacy.md",
                preview: "",
                createdAt: "now"
            )
        ]

        let artifacts = manager.recentArtifacts(for: roomAID)
        XCTAssertEqual(artifacts.map(\.id), ["a"])
        XCTAssertTrue(manager.recentArtifacts(for: roomBID).isEmpty)
    }

    func test_panelTuckGeometry_edgesAndTeamExclusion() {
        let visible = NSRect(x: 0, y: 40, width: 1440, height: 860)
        let frame = NSRect(x: 4, y: 120, width: 420, height: 360)
        XCTAssertEqual(PanelTuckGeometry.nearestTuckEdge(frame: frame, visibleFrame: visible), .left)
        XCTAssertEqual(
            PanelTuckGeometry.nearestTuckEdge(
                frame: NSRect(x: -80, y: 120, width: 420, height: 360),
                visibleFrame: visible
            ),
            .left,
            "가장자리 밖으로 밀어 넣은 창도 tuck 의도로 처리해야 함"
        )
        XCTAssertFalse(PanelTuckGeometry.isTuckAllowed(agentID: "team"))
        XCTAssertFalse(PanelTuckGeometry.isTuckAllowed(agentID: "chat_single"))
        XCTAssertTrue(PanelTuckGeometry.isTuckAllowed(agentID: "swap_window"))

        let tucked = PanelTuckGeometry.tuckedFrame(for: frame, edge: .left, visibleFrame: visible)
        XCTAssertEqual(tucked.maxX, visible.minX + PanelTuckGeometry.revealThickness, accuracy: 0.001)

        let bottom = PanelTuckGeometry.tuckedFrame(for: frame, edge: .bottom, visibleFrame: visible)
        XCTAssertEqual(bottom.maxY, visible.minY + PanelTuckGeometry.revealThickness, accuracy: 0.001)
    }

    func test_bottomAnchoredPanelResizeKeepsComposerEdgeVisible() {
        let visible = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let original = NSRect(x: 980, y: 80, width: 420, height: 480)

        let resized = PanelTuckGeometry.bottomAnchoredResizedFrame(
            original,
            size: NSSize(width: 620, height: 700),
            visibleFrame: visible
        )

        XCTAssertEqual(resized.minY, original.minY, accuracy: 0.001)
        XCTAssertLessThanOrEqual(resized.maxX, visible.maxX - 8)
        XCTAssertLessThanOrEqual(resized.maxY, visible.maxY - 8)
        XCTAssertGreaterThanOrEqual(resized.minX, visible.minX + 8)
    }

    func test_firstLaunchPresentationDoesNotClaimEveryFeatureIsEnabled() {
        let state = FirstLaunchState(
            hasSeenOnboarding: true,
            hasAPIKey: true,
            capabilityMode: .aiEnabled
        )

        let content = FirstLaunchPresentation.content(for: state)

        XCTAssertEqual(content.title, "AI 대화 연결됨")
        XCTAssertFalse(content.title.contains("모든 기능"))
        XCTAssertFalse(content.subtitle.contains("모든 기능"))
        XCTAssertTrue(content.subtitle.contains("외부 서비스"))
        XCTAssertFalse(RuntimeCapabilityMode.aiEnabled.shortMessage.contains("모든 기능"))
        XCTAssertFalse(RuntimeCapabilityMode.aiEnabled.detailedMessage.contains("모두 사용할"))
    }

    func test_firstLaunchWindowPolicyPrioritizesOnboardingUntilSeen() {
        XCTAssertTrue(
            FirstLaunchWindowPolicy.shouldFocusStatusWindow(
                for: FirstLaunchState(hasSeenOnboarding: false)
            )
        )
        XCTAssertFalse(
            FirstLaunchWindowPolicy.shouldFocusStatusWindow(
                for: FirstLaunchState(hasSeenOnboarding: true)
            )
        )
    }

    func test_productSettingsCopyAvoidsDeveloperJargon() {
        XCTAssertEqual(SettingsSurfaceCopy.skillSearchPlaceholder, "스킬 이름이나 설명 검색")
        XCTAssertEqual(SettingsSurfaceCopy.builtInSkillSectionTitle(enabled: 3, total: 5), "기본 스킬 (3/5 활성화)")
        XCTAssertFalse(SettingsSurfaceCopy.skillSearchPlaceholder.contains("ID"))
        XCTAssertFalse(AssistantConnectorUserCopy.permissionTitle.contains("OAuth"))
        XCTAssertFalse(AssistantConnectorUserCopy.pendingSetupMessage.contains("OAuth"))
        XCTAssertEqual(ConnectionCenterUserCopy.storageLocation, "이 Mac")
        XCTAssertFalse(LLMFallbackPolicy.sameProviderOnly.displayName.contains("제공자"))
        XCTAssertFalse(LLMFallbackPolicy.crossProviderAllowed.displayName.contains("제공자"))
    }

    func test_homeDashboardDoesNotDuplicateFeaturedBriefingInPrimaryGrid() throws {
        let briefing = try XCTUnwrap(MyTeamToolRegistry.descriptor(id: "briefing.today"))
        XCTAssertFalse(HomeDashboardLayoutPolicy.shouldIncludeInPrimaryGrid(briefing))
    }

    func test_koreanSubjectParticleMatchesFinalConsonant() {
        XCTAssertEqual(KoreanSubjectParticle.suffix(for: "치코"), "는")
        XCTAssertEqual(KoreanSubjectParticle.suffix(for: "핀"), "은")
    }

    func test_qaRuntimeProfileAcceptsOnlyExplicitAbsoluteRoot() {
        XCTAssertFalse(QARuntimeProfile.isEnabled(arguments: ["MyTeam"]))
        XCTAssertTrue(
            QARuntimeProfile.isEnabled(
                arguments: ["MyTeam", "--qa-root", "/private/tmp/MyTeamQA"]
            )
        )
        XCTAssertFalse(
            KeychainAccessPolicy.allowsAccess(
                arguments: ["MyTeam", "--qa-root", "/private/tmp/MyTeamQA"]
            )
        )
        XCTAssertTrue(KeychainAccessPolicy.allowsAccess(arguments: ["MyTeam"]))
        XCTAssertNil(QARuntimeProfile.rootURL(arguments: ["MyTeam"]))
        XCTAssertNil(QARuntimeProfile.rootURL(arguments: ["MyTeam", "--qa-root", "relative/path"]))
        XCTAssertEqual(
            QARuntimeProfile.rootURL(arguments: ["MyTeam", "--qa-root", "/private/tmp/MyTeamQA"]),
            URL(fileURLWithPath: "/private/tmp/MyTeamQA", isDirectory: true)
        )
    }

    func test_workspaceDirectoryUsesIsolatedQARoot() {
        let qaRoot = URL(fileURLWithPath: "/private/tmp/MyTeamWorkspaceQA", isDirectory: true)
        let workspaceURL = AppPaths.workspaceDirectory(
            arguments: ["MyTeam", "--qa-root", qaRoot.path]
        )

        XCTAssertEqual(
            workspaceURL,
            qaRoot
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("MyTeam", isDirectory: true)
                .appendingPathComponent("Workspace", isDirectory: true)
                .standardizedFileURL
        )
    }

    @MainActor
    func test_appStoreVoiceSurfaceStaysHiddenUntilReleaseApproval() {
        XCTAssertFalse(TTSProductPolicy.userFacingTTSEnabled(for: .appStore))
        XCTAssertFalse(TTSProductPolicy.labEnabled(for: .appStore))
        XCTAssertFalse(SettingsSurfacePolicy.showsVoiceLab(in: .appStore))

        XCTAssertTrue(TTSProductPolicy.userFacingTTSEnabled(for: .debug))
        XCTAssertTrue(TTSProductPolicy.labEnabled(for: .debug))
        XCTAssertTrue(SettingsSurfacePolicy.showsVoiceLab(in: .debug))
    }

    @MainActor
    func test_localSchedulerDelegatedWorkResponseUsesPendingRequestState() {
        let manager = AgentWindowManager.shared
        let roomID = UUID()
        let request = DelegatedExecutionRequest(
            id: UUID(),
            roomID: roomID,
            contractID: UUID(),
            originalMessagePreview: "분기 보고서 초안을 정리해줘",
            normalizedExecutionMessage: "분기 보고서 초안 정리",
            routeHint: "universalDocument",
            status: .pendingApproval,
            createdAt: Date()
        )
        manager.recordPendingDelegatedExecutionRequest(request)
        defer { manager.clearPendingDelegatedExecutionRequest(for: roomID) }

        let response = LocalSchedulerCommandService.response(
            for: LocalSchedulerCommand(
                kind: .showDelegatedWork,
                sourceMessage: "진행 중인 위임 작업 보여줘"
            ),
            roomID: roomID,
            manager: manager
        )

        XCTAssertTrue(response.contains("분기 보고서 초안을 정리해줘"))
        XCTAssertTrue(response.contains("승인 대기"))
        XCTAssertFalse(response.contains("위임 작업이 없습니다"))
    }

    @MainActor
    func test_roomScopedWorkflowStatusMirrorPreservesTheVisibleRoomAndSurvivingWork() {
        let manager = AgentWindowManager.shared
        let originalCurrentRoomID = manager.currentRoomID
        let originalSelectedTeamWorkroomID = manager.selectedTeamWorkroomID
        let roomA = UUID()
        let roomB = UUID()
        defer {
            manager.clearWorkflowStatus(for: roomA)
            manager.clearWorkflowStatus(for: roomB)
            manager.currentRoomID = originalCurrentRoomID
            manager.selectedTeamWorkroomID = originalSelectedTeamWorkroomID
        }

        manager.currentRoomID = roomA
        manager.selectedTeamWorkroomID = roomA
        manager.setWorkflowStatus("A 작업 중", for: roomA)
        manager.setWorkflowStatus("B 작업 중", for: roomB)

        XCTAssertEqual(manager.workflowStatusText(for: roomA), "A 작업 중")
        XCTAssertEqual(manager.workflowStatusText(for: roomB), "B 작업 중")
        XCTAssertEqual(manager.workflowStatusText, "A 작업 중")

        manager.clearWorkflowStatus(for: roomA)

        XCTAssertEqual(manager.workflowStatusText(for: roomB), "B 작업 중")
        XCTAssertEqual(manager.workflowStatusText, "B 작업 중")
    }

    @MainActor
    func test_roomScopedWorkflowIDMirrorDoesNotClearAnotherRoom() {
        let manager = AgentWindowManager.shared
        let originalCurrentRoomID = manager.currentRoomID
        let originalSelectedTeamWorkroomID = manager.selectedTeamWorkroomID
        let roomA = UUID()
        let roomB = UUID()
        let workflowA = UUID()
        let workflowB = UUID()
        defer {
            manager.setCurrentWorkflowID(nil, roomID: roomA)
            manager.setCurrentWorkflowID(nil, roomID: roomB)
            manager.currentRoomID = originalCurrentRoomID
            manager.selectedTeamWorkroomID = originalSelectedTeamWorkroomID
        }

        manager.currentRoomID = roomA
        manager.selectedTeamWorkroomID = roomA
        manager.setCurrentWorkflowID(workflowA, roomID: roomA)
        manager.setCurrentWorkflowID(workflowB, roomID: roomB)

        XCTAssertEqual(manager.currentWorkflowID(for: roomA), workflowA)
        XCTAssertEqual(manager.currentWorkflowID(for: roomB), workflowB)
        XCTAssertEqual(manager.currentWorkflowID, workflowA)

        manager.setCurrentWorkflowID(nil, roomID: roomA)

        XCTAssertEqual(manager.currentWorkflowID(for: roomB), workflowB)
        XCTAssertEqual(manager.currentWorkflowID, workflowB)
    }

    @MainActor
    func test_artifactWorkflowOwnershipUsesTheRequestedRoom() {
        let manager = AgentWindowManager.shared
        let originalCurrentRoomID = manager.currentRoomID
        let originalSelectedTeamWorkroomID = manager.selectedTeamWorkroomID
        let roomA = UUID()
        let roomB = UUID()
        let workflowA = UUID()
        let workflowB = UUID()
        defer {
            manager.setCurrentWorkflowID(nil, roomID: roomA)
            manager.setCurrentWorkflowID(nil, roomID: roomB)
            manager.currentRoomID = originalCurrentRoomID
            manager.selectedTeamWorkroomID = originalSelectedTeamWorkroomID
        }

        manager.currentRoomID = roomA
        manager.selectedTeamWorkroomID = roomA
        manager.setCurrentWorkflowID(workflowA, roomID: roomA)
        manager.setCurrentWorkflowID(workflowB, roomID: roomB)

        XCTAssertEqual(
            ArtifactWorkflowOwnership.workflowID(for: roomB, manager: manager),
            workflowB
        )
        XCTAssertNotEqual(
            ArtifactWorkflowOwnership.workflowID(for: roomB, manager: manager),
            workflowA
        )

        let options = ToolExecutionOptions.scopedStandalone(roomID: roomB)
        XCTAssertEqual(options.roomID, roomB)
        XCTAssertTrue(options.persistIndividualArtifact)
    }

    func test_workflowCompletionReactionRequiresExplicitRoomOwnership() {
        let roomID = UUID()

        XCTAssertEqual(
            WorkflowCompletionRoomResolver.roomID(from: ["roomID": roomID]),
            roomID
        )
        XCTAssertEqual(
            WorkflowCompletionRoomResolver.roomID(from: ["roomID": roomID.uuidString]),
            roomID
        )
        XCTAssertNil(
            WorkflowCompletionRoomResolver.roomID(from: ["artifacts": ["result.md"]])
        )
    }

    func test_workflowCompletionTruthNeverClaimsPlannedWorkAsDone() {
        XCTAssertEqual(
            WorkflowCompletionTruthPolicy.headline(
                planTitle: "출시 문서",
                artifactCount: 0,
                failureCount: 0,
                approvalCount: 0,
                plannedCount: 1,
                unavailableCount: 0
            ),
            "⚠️ 작업 미완료: 출시 문서"
        )
        XCTAssertEqual(
            WorkflowCompletionTruthPolicy.headline(
                planTitle: "메일 초안",
                artifactCount: 0,
                failureCount: 0,
                approvalCount: 1,
                plannedCount: 0,
                unavailableCount: 0
            ),
            "⏸️ 사용자 확인 필요: 메일 초안"
        )
        XCTAssertFalse(WorkflowCompletionTruthPolicy.shouldPostArtifactNotification(artifactCount: 0))
        XCTAssertTrue(WorkflowCompletionTruthPolicy.shouldPostArtifactNotification(artifactCount: 1))
    }

    @MainActor
    func test_cancellingOneRoomPreservesAnotherRoomsRuntimeAndTypingState() async {
        let manager = AgentWindowManager.shared
        let roomA = UUID()
        let roomB = UUID()
        let originalTypingAgentIDs = manager.typingAgentIDs
        let originalTeamRuntimeState = manager.teamRuntimeState
        let originalIsWorkflowRunning = manager.isWorkflowRunning
        let taskA = Task<Void, Never> { try? await Task.sleep(nanoseconds: 30_000_000_000) }
        let taskB = Task<Void, Never> { try? await Task.sleep(nanoseconds: 30_000_000_000) }
        defer {
            taskA.cancel()
            taskB.cancel()
            manager.setActiveWorkflowTask(nil, roomID: roomA)
            manager.setActiveWorkflowTask(nil, roomID: roomB)
            manager.clearWorkflowStatus(for: roomA)
            manager.clearWorkflowStatus(for: roomB)
            manager.typingAgentIDs = originalTypingAgentIDs
            manager.teamRuntimeState = originalTeamRuntimeState
            manager.isWorkflowRunning = originalIsWorkflowRunning
        }

        manager.setActiveWorkflowTask(taskA, roomID: roomA)
        manager.setActiveWorkflowTask(taskB, roomID: roomB)
        manager.setWorkflowStatus("A 작업 중", for: roomA)
        manager.setWorkflowStatus("B 작업 중", for: roomB)
        manager.typingAgentIDs = ["agent_concurrent"]
        manager.teamRuntimeState = .discussionStarted(roomID: roomB)
        manager.isWorkflowRunning = true

        WorkflowOrchestrator.shared.cancelCurrentWorkflow(roomID: roomA, manager: manager)
        for _ in 0..<20 where manager.activeWorkflowTask(for: roomA) != nil {
            await Task.yield()
        }

        XCTAssertNil(manager.activeWorkflowTask(for: roomA))
        XCTAssertNotNil(manager.activeWorkflowTask(for: roomB))
        XCTAssertEqual(manager.workflowStatusText(for: roomB), "B 작업 중")
        XCTAssertEqual(manager.typingAgentIDs, ["agent_concurrent"])
        XCTAssertEqual(manager.teamRuntimeState?.roomID, roomB)
        XCTAssertTrue(manager.isWorkflowRunning)
    }

    @MainActor
    func test_staleWorkflowCleanupCannotClearReplacementTaskInTheSameRoom() {
        let manager = AgentWindowManager.shared
        let roomID = UUID()
        let oldTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 30_000_000_000) }
        let replacementTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 30_000_000_000) }
        defer {
            oldTask.cancel()
            replacementTask.cancel()
            manager.setActiveWorkflowTask(nil, roomID: roomID)
        }

        let oldToken = manager.installActiveWorkflowTask(oldTask, roomID: roomID)
        let replacementToken = manager.installActiveWorkflowTask(replacementTask, roomID: roomID)

        XCTAssertFalse(manager.clearActiveWorkflowTask(roomID: roomID, token: oldToken))
        XCTAssertNotNil(manager.activeWorkflowTask(for: roomID))
        XCTAssertTrue(manager.clearActiveWorkflowTask(roomID: roomID, token: replacementToken))
        XCTAssertNil(manager.activeWorkflowTask(for: roomID))
    }

    @MainActor
    func test_staleWorkflowFinishCannotClearReplacementWorkflowID() {
        let manager = AgentWindowManager.shared
        let roomID = UUID()
        let oldWorkflowID = UUID()
        let replacementWorkflowID = UUID()
        defer { manager.setCurrentWorkflowID(nil, roomID: roomID) }

        manager.setCurrentWorkflowID(oldWorkflowID, roomID: roomID)
        manager.setCurrentWorkflowID(replacementWorkflowID, roomID: roomID)

        XCTAssertFalse(manager.clearCurrentWorkflowID(oldWorkflowID, roomID: roomID))
        XCTAssertEqual(manager.currentWorkflowID(for: roomID), replacementWorkflowID)
        XCTAssertTrue(manager.clearCurrentWorkflowID(replacementWorkflowID, roomID: roomID))
        XCTAssertNil(manager.currentWorkflowID(for: roomID))
    }

    @MainActor
    func test_staleNaturalWorkOperationCannotClearReplacementStatus() {
        let manager = AgentWindowManager.shared
        let roomID = UUID()
        let originalIsWorkflowRunning = manager.isWorkflowRunning
        defer {
            manager.clearWorkflowStatus(for: roomID)
            manager.isWorkflowRunning = originalIsWorkflowRunning
        }

        let oldToken = manager.beginWorkflowOperation(status: "첫 작업", roomID: roomID)
        let replacementToken = manager.beginWorkflowOperation(status: "새 작업", roomID: roomID)

        manager.finishWorkflowOperation(roomID: roomID, token: oldToken)

        XCTAssertEqual(manager.workflowStatusText(for: roomID), "새 작업")
        XCTAssertTrue(manager.isWorkflowRunning)

        manager.finishWorkflowOperation(roomID: roomID, token: replacementToken)

        XCTAssertNil(manager.workflowStatusText(for: roomID))
        XCTAssertFalse(manager.isWorkflowRunning)
    }

    func test_keychainMutationPolicyFailsClosedAndTreatsMissingDeleteAsSuccess() {
        XCTAssertTrue(KeychainMutationPolicy.saveSucceeded(status: errSecSuccess))
        XCTAssertFalse(KeychainMutationPolicy.saveSucceeded(status: errSecAuthFailed))
        XCTAssertTrue(KeychainMutationPolicy.deleteSucceeded(status: errSecSuccess))
        XCTAssertTrue(KeychainMutationPolicy.deleteSucceeded(status: errSecItemNotFound))
        XCTAssertFalse(KeychainMutationPolicy.deleteSucceeded(status: errSecAuthFailed))
    }

    @MainActor
    func test_artifactStoreRefreshesCachedHealthAfterFileChanges() async throws {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("myteam-artifact-health-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        let store = ArtifactStore(workspaceURL: workspaceURL)
        let fileURL = workspaceURL.appendingPathComponent("report.md")
        try Data("version-one".utf8).write(to: fileURL)
        let artifact = IndexedArtifact(
            id: "artifact-health",
            workflowID: "test-workflow",
            title: "Health report",
            type: .report,
            filename: fileURL.lastPathComponent,
            relativePath: fileURL.lastPathComponent,
            preview: "",
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        guard case .success = await store.registerArtifact(artifact) else {
            return XCTFail("The test artifact must be registered")
        }
        try Data("version-two".utf8).write(to: fileURL, options: .atomic)

        let refreshed = await store.loadArtifacts()
        XCTAssertEqual(refreshed.first?.healthStatus, .hashMismatch)
    }

    @MainActor
    func test_recentArtifactCompactionPreservesEntriesWhenArtifactIndexIsCorrupt() async throws {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("myteam-artifact-corrupt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspaceURL) }
        try Data("not-json".utf8).write(to: workspaceURL.appendingPathComponent("artifacts.json"))

        let artifactStore = ArtifactStore(workspaceURL: workspaceURL)
        let runtimeStore = RoomRuntimeStore()
        let entry = RecentArtifactIndexEntry(
            artifactID: "recoverable-artifact",
            roomID: UUID(),
            filename: "report.md",
            artifactType: ArtifactType.report.rawValue,
            createdAt: Date(),
            contentHash: nil,
            fileSizeBytes: nil
        )
        runtimeStore.recentArtifactIndex.add(entry)

        await runtimeStore.compactRecentArtifactIndex(
            using: artifactStore,
            persistChanges: false
        )

        XCTAssertEqual(runtimeStore.recentArtifactIndex.allEntries, [entry])
        XCTAssertNotNil(runtimeStore.recentArtifactIndexPersistenceError)
    }

    @MainActor
    func test_recentArtifactCompactionPreservesEntriesWhenArtifactIndexIsMissing() async throws {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("myteam-artifact-missing-index-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        let artifactStore = ArtifactStore(workspaceURL: workspaceURL)
        let runtimeStore = RoomRuntimeStore()
        let entry = RecentArtifactIndexEntry(
            artifactID: "recoverable-artifact",
            roomID: UUID(),
            filename: "report.md",
            artifactType: ArtifactType.report.rawValue,
            createdAt: Date(),
            contentHash: nil,
            fileSizeBytes: nil
        )
        runtimeStore.recentArtifactIndex.add(entry)

        await runtimeStore.compactRecentArtifactIndex(
            using: artifactStore,
            persistChanges: false
        )

        XCTAssertEqual(runtimeStore.recentArtifactIndex.allEntries, [entry])
        XCTAssertNotNil(runtimeStore.recentArtifactIndexPersistenceError)
    }

    func test_ttsRuntimeProbeRejectsMissingOrEmptyAudio() throws {
        XCTAssertNotNil(TTSRuntimeProbeValidation.failureReason(output: nil))

        let emptyWAV = FileManager.default.temporaryDirectory
            .appendingPathComponent("myteam-empty-tts-probe.wav")
        try Data().write(to: emptyWAV)
        defer { try? FileManager.default.removeItem(at: emptyWAV) }

        let output = TTSOutput(
            audioFileURL: emptyWAV,
            duration: 0,
            sampleRate: 24_000,
            providerKind: .supertonic3
        )
        XCTAssertNotNil(TTSRuntimeProbeValidation.failureReason(output: output))
    }

    func test_fileIntake_readsPDFIntoStructuredMarkdown() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-file-intake-test.pdf")
        try makeSamplePDF(at: tempURL, text: "회의 목적\n이번 주 우선순위를 정리합니다.")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let request = try FileIntakeService.makeRequest(fileURL: tempURL, source: .filePicker)
        let result = FileIntakeService.readText(from: request)

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.detectedFormat, .pdf)
        XCTAssertTrue(result.normalizedText?.contains("## 문서 개요") == true)
        XCTAssertTrue(result.normalizedText?.contains("## 페이지 1") == true)
        XCTAssertTrue(result.normalizedText?.contains("이번 주 우선순위") == true)
    }

    func test_fileIntake_readsXLSXIntoStructuredMarkdown() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-file-intake-test.xlsx")
        let plan = WorkbookPlan(
            format: "xlsx-plan-v1",
            title: "매출현황",
            sheets: [
                SheetPlan(
                    name: "매출현황",
                    headers: ["월", "매출", "비고"],
                    rows: [["1월", "1200000", "프로모션 포함"], ["2월", "980000", ""]],
                    summary: nil
                )
            ]
        )
        _ = try XLSXWriter().write(plan: plan, to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let request = try FileIntakeService.makeRequest(fileURL: tempURL, source: .filePicker)
        let result = FileIntakeService.readText(from: request)

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.detectedFormat, .xlsx)
        XCTAssertTrue(result.normalizedText?.contains("## 시트: 매출현황") == true)
        XCTAssertTrue(result.normalizedText?.contains("| 월 | 매출 | 비고 |") == true)
        XCTAssertTrue(result.normalizedText?.contains("프로모션 포함") == true)
    }

    func test_fileIntake_readsDOCXIntoStructuredMarkdown() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-file-intake-test.docx")
        try makeSampleDOCX(
            at: tempURL,
            headerText: "MyTeam 주간 회의",
            footerText: "Confidential",
            paragraphs: ["회의 목적", "이번 주 우선순위를 정리합니다."],
            listItems: ["API QA 정리", "배포 체크"],
            tableRows: [["담당", "할 일"], ["치코", "QA 정리"]]
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let request = try FileIntakeService.makeRequest(fileURL: tempURL, source: .filePicker)
        let result = FileIntakeService.readText(from: request)

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.detectedFormat, .docx)
        XCTAssertTrue(result.normalizedText?.contains("## 문서 개요") == true)
        XCTAssertTrue(result.normalizedText?.contains("## 머리말/꼬리말") == true)
        XCTAssertTrue(result.normalizedText?.contains("MyTeam 주간 회의") == true)
        XCTAssertTrue(result.normalizedText?.contains("Confidential") == true)
        XCTAssertTrue(result.normalizedText?.contains("회의 목적") == true)
        XCTAssertTrue(result.normalizedText?.contains("- API QA 정리") == true)
        XCTAssertTrue(result.normalizedText?.contains("| 담당 | 할 일 |") == true)
        XCTAssertTrue(result.normalizedText?.contains("QA 정리") == true)
    }

    func test_fileIntake_readsPPTXIntoStructuredMarkdown() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("codex-file-intake-test.pptx")
        try makeSamplePPTXWithNotesAndTable(at: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let request = try FileIntakeService.makeRequest(fileURL: tempURL, source: .filePicker)
        let result = FileIntakeService.readText(from: request)

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.detectedFormat, .pptx)
        XCTAssertTrue(result.normalizedText?.contains("## 슬라이드 1") == true)
        XCTAssertTrue(result.normalizedText?.contains("이번 주 목표") == true)
        XCTAssertTrue(result.normalizedText?.contains("### 표 1") == true)
        XCTAssertTrue(result.normalizedText?.contains("| 담당 | 상태 |") == true)
        XCTAssertTrue(result.normalizedText?.contains("### 발표자 노트") == true)
        XCTAssertTrue(result.normalizedText?.contains("데모에서 일정 언급") == true)
    }

    private func makeSamplePDF(at url: URL, text: String) throws {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        textView.string = text
        textView.font = .systemFont(ofSize: 16)
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try pdfData.write(to: url)
    }

    private func makeSampleDOCX(
        at url: URL,
        headerText: String,
        footerText: String,
        paragraphs: [String],
        listItems: [String],
        tableRows: [[String]]
    ) throws {
        let zip = MiniZipWriter()
        let bodyParagraphs = paragraphs.map {
            "<w:p><w:r><w:t>\(escapedXML($0))</w:t></w:r></w:p>"
        }.joined()
        let bodyListItems = listItems.map {
            """
            <w:p>
              <w:pPr>
                <w:pStyle w:val="ListParagraph"/>
                <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>
              </w:pPr>
              <w:r><w:t>\(escapedXML($0))</w:t></w:r>
            </w:p>
            """
        }.joined()
        let tableXML: String
        if tableRows.isEmpty {
            tableXML = ""
        } else {
            let rows = tableRows.map { row in
                let cells = row.map { value in
                    "<w:tc><w:p><w:r><w:t>\(escapedXML(value))</w:t></w:r></w:p></w:tc>"
                }.joined()
                return "<w:tr>\(cells)</w:tr>"
            }.joined()
            tableXML = "<w:tbl>\(rows)</w:tbl>"
        }

        zip.addEntry(name: "[Content_Types].xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """)
        zip.addEntry(name: "_rels/.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """)
        zip.addEntry(name: "word/_rels/document.xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
        </Relationships>
        """)
        zip.addEntry(name: "word/document.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            \(bodyParagraphs)
            \(bodyListItems)
            \(tableXML)
          </w:body>
        </w:document>
        """)
        zip.addEntry(name: "word/header1.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:p><w:r><w:t>\(escapedXML(headerText))</w:t></w:r></w:p>
        </w:hdr>
        """)
        zip.addEntry(name: "word/footer1.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:p><w:r><w:t>\(escapedXML(footerText))</w:t></w:r></w:p>
        </w:ftr>
        """)

        try zip.build().write(to: url)
    }

    private func escapedXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func makeSamplePPTXWithNotesAndTable(at url: URL) throws {
        let zip = MiniZipWriter()
        zip.addEntry(name: "[Content_Types].xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
          <Override PartName="/ppt/notesSlides/notesSlide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"/>
        </Types>
        """)
        zip.addEntry(name: "_rels/.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """)
        zip.addEntry(name: "ppt/presentation.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
        </p:presentation>
        """)
        zip.addEntry(name: "ppt/_rels/presentation.xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
        </Relationships>
        """)
        zip.addEntry(name: "ppt/slides/slide1.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
               xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:cSld>
            <p:spTree>
              <p:sp>
                <p:txBody>
                  <a:bodyPr/><a:lstStyle/>
                  <a:p><a:r><a:t>이번 주 목표</a:t></a:r></a:p>
                </p:txBody>
              </p:sp>
              <p:graphicFrame>
                <a:graphic>
                  <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">
                    <a:tbl>
                      <a:tr>
                        <a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>담당</a:t></a:r></a:p></a:txBody></a:tc>
                        <a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>상태</a:t></a:r></a:p></a:txBody></a:tc>
                      </a:tr>
                      <a:tr>
                        <a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>치코</a:t></a:r></a:p></a:txBody></a:tc>
                        <a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>진행중</a:t></a:r></a:p></a:txBody></a:tc>
                      </a:tr>
                    </a:tbl>
                  </a:graphicData>
                </a:graphic>
              </p:graphicFrame>
            </p:spTree>
          </p:cSld>
        </p:sld>
        """)
        zip.addEntry(name: "ppt/slides/_rels/slide1.xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide" Target="../notesSlides/notesSlide1.xml"/>
        </Relationships>
        """)
        zip.addEntry(name: "ppt/notesSlides/notesSlide1.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:notes xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:sp>
                <p:txBody>
                  <a:bodyPr/><a:lstStyle/>
                  <a:p><a:r><a:t>데모에서 일정 언급</a:t></a:r></a:p>
                </p:txBody>
              </p:sp>
            </p:spTree>
          </p:cSld>
        </p:notes>
        """)
        try zip.build().write(to: url)
    }
}
