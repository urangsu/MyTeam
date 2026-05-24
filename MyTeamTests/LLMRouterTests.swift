import XCTest
@testable import MyTeam

// MARK: - LLMRouterTests
// Round 270C: Behavioral tests for LLM routing logic.
// Tests run against real code paths using @testable import;
// no network calls are made.

final class LLMRouterTests: XCTestCase {

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

    // MARK: - Test 2: requiresToolUse=true 순서 알고리즘 확인

    func test_toolUse_routesToToolCapableFirst() {
        let service = AIService.shared
        // 순서 알고리즘 검증:
        // requiresToolUse=true + preferred=gemini(비tool-capable) → tool-capable(Claude/OpenAI)이 먼저
        // requiresToolUse=false → preferred(Gemini)가 먼저
        let withTool = service.providerCandidates(preferred: .gemini, requiresToolUse: true)
        let withoutTool = service.providerCandidates(preferred: .gemini, requiresToolUse: false)

        // 1) 항상 후보 목록이 비어있지 않아야 함 (최소 1개 provider)
        XCTAssertFalse(withTool.isEmpty, "requiresToolUse=true여도 후보 목록이 비어있으면 안 됨")

        // 2) API 키가 있는 tool-capable provider가 존재하면 requiresToolUse 경로에서 먼저 나와야 함
        let toolCapable: Set<LLMProvider> = [.claude, .openAI]
        let availableToolCapable = withTool.filter { toolCapable.contains($0) }
        let availableNonTool = withTool.filter { !toolCapable.contains($0) }

        if !availableToolCapable.isEmpty {
            // tool-capable이 있으면 반드시 non-tool-capable보다 앞에 와야 함
            let firstToolCapableIdx = withTool.firstIndex(where: { toolCapable.contains($0) }) ?? Int.max
            let firstNonToolIdx = withTool.firstIndex(where: { !toolCapable.contains($0) }) ?? Int.max
            XCTAssertLessThan(firstToolCapableIdx, firstNonToolIdx,
                              "tool-capable provider가 먼저 나와야 함")
        } else {
            // tool-capable API 키 없음 → 가용한 provider(예: Gemini)로 폴백, 이것도 올바른 동작
            XCTAssertFalse(availableNonTool.isEmpty,
                           "tool-capable 키 없을 때 다른 가용 provider로 폴백되어야 함")
        }

        // 3) requiresToolUse=false이면 preferred(Gemini)가 첫 번째
        if let first = withoutTool.first {
            XCTAssertEqual(first, .gemini,
                           "requiresToolUse=false이면 preferred provider가 첫 번째여야 함")
        }
    }

    func test_toolNeedClassifier_usesUserTextNotGroundedContext() {
        XCTAssertFalse(
            ToolNeedClassifier.needsTool("오늘 회의록 정리해줘"),
            "일반 문서 요청은 도구 라우팅으로 과잉 분류하면 안 됨"
        )
        XCTAssertTrue(
            ToolNeedClassifier.needsTool("웹에서 최신 자료 찾아서 정리해줘"),
            "명시적 웹/검색 요청은 tool-capable provider 후보를 우선해야 함"
        )
        XCTAssertTrue(
            ToolNeedClassifier.needsTool("첨부한 내용 요약해줘", hasAttachments: true),
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
        XCTAssertTrue(PanelTuckGeometry.isTuckAllowed(agentID: "chat_single"))

        let tucked = PanelTuckGeometry.tuckedFrame(for: frame, edge: .left, visibleFrame: visible)
        XCTAssertEqual(tucked.maxX, visible.minX + PanelTuckGeometry.revealThickness, accuracy: 0.001)

        let bottom = PanelTuckGeometry.tuckedFrame(for: frame, edge: .bottom, visibleFrame: visible)
        XCTAssertEqual(bottom.maxY, visible.minY + PanelTuckGeometry.revealThickness, accuracy: 0.001)
    }
}
