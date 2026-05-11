import AppKit
import SwiftUI
import Foundation
import Combine

// MARK: - AgentWindowManager
// 팀 테이블 창 1개를 생성하고, 4명의 에이전트를 그 안에 표시합니다.
// AgentConfig → AgentConfig.swift / ChatRoom, ChatLog → ChatModels.swift 로 분리됨
class AgentWindowManager: ObservableObject {

    static let shared = AgentWindowManager()

    // ── 구매 가능하거나 보유한 전체 에이전트 목록 (DB/API 연동 전 임시 데이터) ──
    // spriteName: Assets에 등록된 PNG 시퀀스 파일명 접두사
    //   - 완성된 캐릭터: "sloth", "dog" (스프라이트 사용)
    //   - 미완성 캐릭터: nil (이모지 폴백)
    let allAvailableAgents: [AgentConfig] = [
        AgentConfig(id: "agent_1",  name: "레오",   role: "비지니스 전략가",    emoji: "🦊", color: .orange, isPremium: false, status: "시장 전략 분석 중",         spriteName: nil, fallbackImageName: "레오_profile", dragEmoji: "😤", dragRotation: -12, dragSoundName: "Pop",   dropSoundName: "Funk"),
        AgentConfig(id: "agent_2",  name: "루나",   role: "마케터/콘텐츠 기획", emoji: "🐰", color: .pink,   isPremium: false, status: "바이럴 캠페인 기획 중",    spriteName: nil, fallbackImageName: "루나_profile", dragEmoji: "😆", dragRotation:  10, dragSoundName: "Blow",  dropSoundName: "Pop"),
        AgentConfig(id: "agent_3",  name: "모코",   role: "프로젝트 매니저",    emoji: "🐹", color: .purple, isPremium: false, status: "이미 다 계획해둔 마스터",  spriteName: nil, fallbackImageName: "모코_profile", dragEmoji: "😵", dragRotation:  -8, dragSoundName: "Morse", dropSoundName: "Funk"),
        AgentConfig(id: "agent_4",  name: "핀",     role: "UI 디자이너",        emoji: "🐧", color: .cyan,   isPremium: false, status: "픽셀 하나에 30분째 고민", spriteName: nil, fallbackImageName: "핀_profile", dragEmoji: "😱", dragRotation:  12, dragSoundName: "Ping",  dropSoundName: "Pop"),
        AgentConfig(id: "agent_5",  name: "치코",   role: "UX 디자이너",        emoji: "🐿️", color: Color(red:0.6, green:0.4, blue:0.2), isPremium: true, status: "감성을 데이터로 변환 중",  spriteName: "치코", fallbackImageName: "치코_profile", dragEmoji: "🤯", dragRotation: -10, dragSoundName: "Pop",   dropSoundName: "Funk"),
        AgentConfig(id: "agent_6",  name: "렉스",   role: "법률 전문가",        emoji: "🦥", color: .green,  isPremium: true,  status: "계약서 검토 중 (천천히)", spriteName: nil, fallbackImageName: "렉스_profile", dragEmoji: "😴", dragRotation:  14, dragSoundName: "Blow",  dropSoundName: "Pop"),
        AgentConfig(id: "agent_7",  name: "케이",   role: "보안/데이터 전문가", emoji: "🐕", color: .blue,   isPremium: true,  status: "보안 로그 분석 중",       spriteName: nil, fallbackImageName: "케이_profile", dragEmoji: "😐", dragRotation:  -5, dragSoundName: "Morse", dropSoundName: "Funk"),
        AgentConfig(id: "agent_8",  name: "래키",   role: "백엔드 개발자",      emoji: "🦝", color: .gray,   isPremium: true,  status: "밤새워 API 디버깅 중",    spriteName: nil, fallbackImageName: "래키_profile", dragEmoji: "😵‍💫", dragRotation:   8, dragSoundName: "Ping",  dropSoundName: "Pop"),
        AgentConfig(id: "agent_9",  name: "폴라",   role: "세일즈/BD",          emoji: "🐻‍❄️", color: Color(red:0.2, green:0.6, blue:0.9), isPremium: true, status: "아무도 거절 못 하는 딜 클로징", spriteName: nil, fallbackImageName: "폴라_profile", dragEmoji: "😊", dragRotation: -6, dragSoundName: "Pop",   dropSoundName: "Funk"),
        AgentConfig(id: "agent_10", name: "몽몽",   role: "고객 서비스",        emoji: "🐩", color: Color(red:1.0, green:0.7, blue:0.0), isPremium: true, status: "고객을 팬으로 만드는 중",  spriteName: nil, fallbackImageName: "몽몽_profile", dragEmoji: "🥰", dragRotation:  10, dragSoundName: "Blow",  dropSoundName: "Pop"),
        AgentConfig(id: "agent_11", name: "올리버", role: "QA 엔지니어",        emoji: "🐷", color: .red,    isPremium: true,  status: "버그 사냥 중",            spriteName: nil, fallbackImageName: "올리버_profile", dragEmoji: "😤", dragRotation:  -9, dragSoundName: "Morse", dropSoundName: "Funk"),
    ]
    
    // ── 전역 설정 ──
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("isVoiceMode") var isVoiceMode: Bool = true
    @AppStorage("isSilentMode") var isSilentMode: Bool = false {
        didSet {
            // 무음 모드 켜지면 즉시 모든 음성 중단
            if isSilentMode {
                SpeechManager.shared.stopSpeaking()
            }
        }
    }
    @AppStorage("userLocation") var userLocation: String = "전남 광양"

    // ── 방 목록 (UserDefaults 영속화) ──
    @Published var rooms: [ChatRoom] = [] {
        didSet { saveRooms() }
    }
    @Published var currentRoomID: UUID?
    @Published var isSchedulePanelPresented: Bool = false

    // 호환성: 현재 방의 메시지 접근
    var teamChatLogs: [ChatLog] {
        rooms.first(where: { $0.id == currentRoomID })?.messages.filter { !$0.isSystem } ?? []
    }

    // 팀 전체 대화용 고정 config
    static let teamRepresentative = AgentConfig(
        id: "team_all", name: "팀 채팅", role: "전체 대화방",
        emoji: "🤝", color: .blue, isPremium: false,
        status: "팀 프로젝트 진행 중", spriteName: nil, fallbackImageName: "",
        dragEmoji: "🤝", dragRotation: 0, dragSoundName: "", dropSoundName: ""
    )

    // 팀의 현재 큰 업무
    @Published var currentMainTask: String = "AI 팀 프로젝트 매니징 및 고도화"
    
    // 팀 전체 설정 — 현재 화면에 나와있는 4명의 에이전트 (순서 변경 및 교체 가능)
    @Published var activeAgents: [AgentConfig]

    // ── 감정-스프라이트 연결 ──────────────────────────────────────
    /// 현재 TTS 재생 중인 에이전트 ID (nil = 아무도 말하지 않음)
    @Published var speakingAgentID: String? = nil
    /// 에이전트별 현재 감정 상태 (agentID → AnimationState)
    @Published var agentEmotions: [String: AnimationState] = [:]
    /// 현재 타이핑 중인 에이전트 ID Set (카톡 "..." 인디케이터용)
    @Published var typingAgentIDs: Set<String> = []
    /// Workflow 실행 중 여부 — WorkflowOrchestrator가 set, UI가 중지 버튼 표시에 사용
    @Published var isWorkflowRunning: Bool = false
    /// 현재 실행 중인 workflow UUID — RuntimeDiagnosticsService 및 UI 진행 표시에 사용.
    /// workflow 완료/실패/취소 시 nil로 리셋.
    @Published var currentWorkflowID: UUID? = nil
    /// 현재 팀 협업 런타임 상태 — 팀 토론/화자 선택/턴 진행을 UI에 반영.
    @Published var teamRuntimeState: TeamRuntimeState? = nil
    /// room별 마지막 turn profile — /why, /last, diagnostics용 읽기 전용 상태.
    @Published var lastTurnProfileByRoom: [UUID: TurnProfile] = [:]
    /// room별 마지막 goal interpretation — 관측용 상태.
    @Published var lastGoalInterpretationsByRoom: [UUID: GoalInterpretation] = [:]
    /// room별 마지막 capability route decision — 관측용 상태.
    @Published var lastCapabilityRouteDecisionsByRoom: [UUID: CapabilityRouteDecision] = [:]
    /// room별 마지막 universal document type — 관측용 상태.
    @Published var lastUniversalDocumentTypesByRoom: [UUID: UniversalDocumentSkillType] = [:]
    /// room별 route trace — 최근 route 판단 흐름 기록.
    @Published var routeTracesByRoom: [UUID: [RouteTrace]] = [:]
    /// room별 delegation mode 상태.
    @Published var delegationModeStatesByRoom: [UUID: DelegationModeState] = [:]
    /// room별 delegation contract.
    @Published var activeDelegationContractsByRoom: [UUID: DelegationContract] = [:]
    /// room별 delegation workflow plan.
    @Published var delegatedWorkflowPlansByRoom: [UUID: DelegatedWorkflowPlan] = [:]
    /// room별 pending delegated execution request.
    @Published var pendingDelegatedExecutionRequestsByRoom: [UUID: DelegatedExecutionRequest] = [:]
    /// 최근 완료된 workflow artifact 목록 — 채팅 하단 ArtifactCardView에 표시.
    /// TODO: room scope 분리 — 현재는 앱 전역이라 여러 채팅방에서 artifact가 섞일 수 있음.
    ///       제품 구조에서는 recentArtifactsByRoom: [UUID: [IndexedArtifact]] 또는
    ///       ChatRoom에 artifacts 필드를 붙여야 한다. 데모 이후 우선 적용.
    @Published var recentArtifacts: [IndexedArtifact] = []
    
    // ── 지능형 기억 보호 (Key Fact Buffer) ──
    // V1: 단일 전역 배열 (하위 호환 유지)
    @AppStorage("keyFacts") private var keyFactsData: Data = Data()
    @Published var keyFacts: [String] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(keyFacts) {
                keyFactsData = data
            }
        }
    }
    // V2: scope별 사전 (global / room_{uuid} / char_{name})
    // 형식: { "global": ["...", ...], "room_XXXX": [...], "char_루나": [...] }
    @AppStorage("MyTeam.keyFactsV2") private var keyFactsScopedData: Data = Data()
    private var keyFactsScoped: [String: [String]] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(keyFactsScoped) {
                keyFactsScopedData = data
            }
        }
    }

    @AppStorage("automationTasks") private var automationTasksData: Data = Data()
    @Published var automationTasks: [AutomationTask] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(automationTasks) {
                automationTasksData = data
            }
        }
    }

    let roomRuntimeStore = RoomRuntimeStore()
    private var roomRuntimeStoreCancellable: AnyCancellable?

    @MainActor
    func recordTurnProfile(_ profile: TurnProfile) {
        lastTurnProfileByRoom[profile.roomID] = profile
    }

    @MainActor
    func appendRouteTrace(_ trace: RouteTrace) {
        var traces = routeTracesByRoom[trace.roomID] ?? []
        traces.append(trace)
        if traces.count > 50 {
            traces = Array(traces.suffix(50))
        }
        routeTracesByRoom[trace.roomID] = traces
    }

    @MainActor
    func lastTurnProfile(for roomID: UUID) -> TurnProfile? {
        lastTurnProfileByRoom[roomID]
    }

    @MainActor
    func recordGoalInterpretation(_ goal: GoalInterpretation, decision: CapabilityRouteDecision, roomID: UUID) {
        lastGoalInterpretationsByRoom[roomID] = goal
        lastCapabilityRouteDecisionsByRoom[roomID] = decision
    }

    @MainActor
    func recordUniversalDocumentType(_ type: UniversalDocumentSkillType, roomID: UUID) {
        lastUniversalDocumentTypesByRoom[roomID] = type
    }

    @MainActor
    func lastGoalInterpretation(for roomID: UUID) -> GoalInterpretation? {
        lastGoalInterpretationsByRoom[roomID]
    }

    @MainActor
    func lastCapabilityRouteDecision(for roomID: UUID) -> CapabilityRouteDecision? {
        lastCapabilityRouteDecisionsByRoom[roomID]
    }

    @MainActor
    func lastUniversalDocumentType(for roomID: UUID) -> UniversalDocumentSkillType? {
        lastUniversalDocumentTypesByRoom[roomID]
    }

    @MainActor
    func recentRouteTraces(for roomID: UUID, limit: Int = 50) -> [RouteTrace] {
        Array((routeTracesByRoom[roomID] ?? []).suffix(limit))
    }

    @MainActor
    func updateDelegationModeState(_ state: DelegationModeState) {
        delegationModeStatesByRoom[state.roomID] = state
    }

    @MainActor
    func recordDelegationContract(_ contract: DelegationContract) {
        activeDelegationContractsByRoom[contract.roomID] = contract
    }

    @MainActor
    func recordDelegatedWorkflowPlan(_ plan: DelegatedWorkflowPlan) {
        delegatedWorkflowPlansByRoom[plan.roomID] = plan
    }

    @MainActor
    func delegationModeState(for roomID: UUID) -> DelegationModeState? {
        delegationModeStatesByRoom[roomID]
    }

    @MainActor
    func activeDelegationContract(for roomID: UUID) -> DelegationContract? {
        activeDelegationContractsByRoom[roomID]
    }

    @MainActor
    func delegatedWorkflowPlan(for roomID: UUID) -> DelegatedWorkflowPlan? {
        delegatedWorkflowPlansByRoom[roomID]
    }

    @MainActor
    func recordPendingDelegatedExecutionRequest(_ request: DelegatedExecutionRequest) {
        pendingDelegatedExecutionRequestsByRoom[request.roomID] = request
    }

    @MainActor
    func recordFileIntakeResult(_ result: FileIntakeResult, roomID: UUID) {
        roomRuntimeStore.recordFileIntakeResult(result, roomID: roomID)
    }

    @MainActor
    func pendingDelegatedExecutionRequest(for roomID: UUID) -> DelegatedExecutionRequest? {
        pendingDelegatedExecutionRequestsByRoom[roomID]
    }

    @MainActor
    func lastFileIntakeResult(for roomID: UUID) -> FileIntakeResult? {
        roomRuntimeStore.lastFileIntakeResult(for: roomID)
    }

    @MainActor
    func clearPendingDelegatedExecutionRequest(for roomID: UUID) {
        pendingDelegatedExecutionRequestsByRoom.removeValue(forKey: roomID)
    }

    @MainActor
    func updateRoomGoalContext(
        roomID: UUID,
        goal: GoalInterpretation? = nil,
        activeWorkflowStep: String? = nil,
        recentArtifactID: UUID? = nil
    ) {
        roomRuntimeStore.updateRoomGoalContext(
            roomID: roomID,
            goal: goal,
            activeWorkflowStep: activeWorkflowStep,
            recentArtifactID: recentArtifactID
        )
    }

    @MainActor
    func roomGoalContext(for roomID: UUID) -> RoomGoalContext? {
        roomRuntimeStore.roomGoalContext(for: roomID)
    }

    func activeWorkflowTaskCount() -> Int {
        roomRuntimeStore.activeTaskRoomCount
    }

    @MainActor
    func activeWorkflowTask(for roomID: UUID) -> Task<Void, Never>? {
        roomRuntimeStore.activeTask(for: roomID)
    }

    @MainActor
    func setActiveWorkflowTask(_ task: Task<Void, Never>?, roomID: UUID) {
        roomRuntimeStore.setActiveTask(task, for: roomID)
    }

    @MainActor
    func cancelActiveWorkflowTask(roomID: UUID) {
        _ = roomRuntimeStore.cancelActiveTask(for: roomID)
    }

    @MainActor
    func cancelAllActiveWorkflowTasks() {
        roomRuntimeStore.cancelAllTasks()
    }
    
    var persistentContext: String {
        guard !keyFacts.isEmpty else { return "" }
        return "\n[기억해야 할 핵심 정보]\n" + keyFacts.map { "- \($0)" }.joined(separator: "\n") + "\n"
    }

    /// scope별 기억을 병합해 시스템 프롬프트 컨텍스트 반환.
    /// - agentName: 현재 에이전트 이름 (캐릭터 scope 조회용)
    /// - roomID: 현재 방 ID (room scope 조회용)
    func scopedMemoryContext(agentName: String, roomID: UUID?) -> String {
        var facts: [String] = []
        // 1. 전역 (수석님 관련) 기억
        facts += keyFactsScoped["global"] ?? []
        // 2. 방별 기억
        if let rid = roomID { facts += keyFactsScoped["room_\(rid.uuidString)"] ?? [] }
        // 3. 캐릭터별 기억
        facts += keyFactsScoped["char_\(agentName)"] ?? []
        // 4. 레거시 전역 기억 (V1 keyFacts — 마이그레이션 전까지 포함)
        facts += keyFacts
        // 중복 제거
        facts = NSOrderedSet(array: facts).array.compactMap { $0 as? String }
        guard !facts.isEmpty else { return "" }
        return "\n[기억해야 할 핵심 정보]\n" + facts.map { "- \($0)" }.joined(separator: "\n") + "\n"
    }

    // MARK: - Scoped Key Facts API

    enum MemoryScope {
        case global
        case room(UUID)
        case character(String)
        var key: String {
            switch self {
            case .global:           return "global"
            case .room(let id):     return "room_\(id.uuidString)"
            case .character(let n): return "char_\(n)"
            }
        }
        var label: String {
            switch self {
            case .global:           return "전체 기억"
            case .room:             return "방 기억"
            case .character(let n): return "\(n) 전용 기억"
            }
        }
    }

    func addScopedFact(_ fact: String, scope: MemoryScope) {
        let cleaned = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        var bucket = keyFactsScoped[scope.key] ?? []
        if !bucket.contains(cleaned) {
            bucket.append(cleaned)
            keyFactsScoped[scope.key] = bucket
        }
    }

    func forgetScopedFact(matching query: String, scope: MemoryScope?) -> Int {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return 0 }
        if let scope {
            let before = keyFactsScoped[scope.key]?.count ?? 0
            keyFactsScoped[scope.key]?.removeAll { $0.lowercased().contains(q) }
            return before - (keyFactsScoped[scope.key]?.count ?? 0)
        } else {
            // 전체 scope에서 삭제
            var total = 0
            for key in keyFactsScoped.keys {
                let before = keyFactsScoped[key]?.count ?? 0
                keyFactsScoped[key]?.removeAll { $0.lowercased().contains(q) }
                total += before - (keyFactsScoped[key]?.count ?? 0)
            }
            return total
        }
    }

    func allScopedFacts(agentName: String, roomID: UUID?) -> [(scope: String, facts: [String])] {
        var result: [(String, [String])] = []
        if let g = keyFactsScoped["global"], !g.isEmpty { result.append(("🌐 전체", g)) }
        if let rid = roomID, let r = keyFactsScoped["room_\(rid.uuidString)"], !r.isEmpty { result.append(("🏠 이 방", r)) }
        if let c = keyFactsScoped["char_\(agentName)"], !c.isEmpty { result.append(("👤 \(agentName)", c)) }
        if !keyFacts.isEmpty { result.append(("📌 레거시", keyFacts)) }
        return result
    }
    
    // 팀 테이블 창 (하나)
    private var teamPanel: FloatingPanel?

    // 팀 명칭 드래그와 같이 창 이동을 위해 TeamTableView에 노출
    var teamPanelWindow: FloatingPanel? { teamPanel }

    // 개별 채팅 창 목록 (에이전트 ID별로 관리)
    private var chatPanels: [String: FloatingPanel] = [:]
    
    // 에이전트 교체 창
    private var swapPanel: FloatingPanel?
    
    // 팀 협업 현황 창
    private var statusPanel: FloatingPanel?
    
    // 설정 창
    private var settingsPanel: FloatingPanel?
    
    // 개별 커스텀 설정 창
    private var agentSettingsPanel: FloatingPanel?

    private var lastInteractionTime: Date = Date()
    private var idleTimer: Timer?
    private var automationTimer: Timer?

    private init() {
        activeAgents = Array(allAvailableAgents.prefix(4))
        for index in activeAgents.indices {
            activeAgents[index].applyDeskRouting(index: index)
        }

        // 채팅 데이터 복원
        loadRooms()
        
        if rooms.isEmpty {
            let defaultRoom = ChatRoom(id: UUID(), name: "기본 프로젝트",
                messages: [], agentIDs: ["team_all"], createdAt: Date())
            rooms.append(defaultRoom)
            currentRoomID = defaultRoom.id
        } else {
            currentRoomID = rooms.first?.id
        }
        
        // Key Facts 복구 (V1 레거시)
        if let decoded = try? JSONDecoder().decode([String].self, from: keyFactsData) {
            keyFacts = decoded
        }
        // Key Facts 복구 (V2 scoped)
        if let decoded = try? JSONDecoder().decode([String: [String]].self, from: keyFactsScopedData) {
            keyFactsScoped = decoded
        }
        if let decoded = try? JSONDecoder().decode([AutomationTask].self, from: automationTasksData) {
            automationTasks = decoded
        }

        roomRuntimeStoreCancellable = roomRuntimeStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // 잠금 해제 감지 (didWake만 — sessionDidBecomeActive는 앱 시작 시도 발화해서 중복 유발)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)

        // WorkflowEngine 완료 시 recentArtifacts 갱신 (채팅에서 ArtifactCardView 표시)
        // userInfo["workflowID"] 기준으로 방금 완료된 workflow의 artifact만 표시.
        // "sessionID" 키는 하위 호환 fallback (경고 기록 후 사용).
        NotificationCenter.default.addObserver(
            forName: .workflowCompleted, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let workflowID: String?
            if let wid = notification.userInfo?["workflowID"] as? String {
                workflowID = wid
            } else if let sid = notification.userInfo?["sessionID"] as? String {
                // 구버전 호환 — 새 코드에서는 "workflowID" 키를 사용한다
                AppLog.warning("[AgentWindowManager] workflowCompleted: 'sessionID' fallback 사용 — 'workflowID' 키로 통일 필요")
                workflowID = sid
            } else {
                workflowID = nil
            }

            Task {
                let all = await ArtifactStore.shared.loadArtifacts()
                let recent: [IndexedArtifact]
                if let wid = workflowID {
                    recent = all.filter { $0.workflowID == wid }
                } else {
                    AppLog.warning("[AgentWindowManager] workflowCompleted에 workflowID 없음 — suffix(5) fallback (데이터 오염 위험)")
                    recent = Array(all.suffix(5))
                }
                // Task.yield: 현재 layout pass 완료 후 업데이트 — layout recursion 방지
                await Task.yield()
                await MainActor.run { self.recentArtifacts = recent }
            }
        }

        // 앱 최초 시작 인사말 — 랜덤 1명만
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.handleStartup() }

        // 아이들 감지 타이머 (1분마다 체크)
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
        automationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.runDueAutomationTasks()
        }
    }

    func updateInteractionTime() { lastInteractionTime = Date() }

    // MARK: - 윈도우 정돈 기능
    func arrangeWindows() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 20
        
        // 1. 메인 에이전트 창 (하단 중앙, Dock 위)
        if let teamPanel = teamPanel {
            let panelFrame = teamPanel.frame
            let x = visibleFrame.midX - (panelFrame.width / 2)
            let y = visibleFrame.minY + padding
            teamPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 2. 협업 상태창 및 개별 대화창 (우측 가장자리에 차곡차곡 정렬)
        var currentY = visibleFrame.maxY - padding
        let rightX = visibleFrame.maxX - padding
        let spacing: CGFloat = 16
        
        // 협업창이 안 켜져있으면 먼저 켬
        if statusPanel?.isVisible != true {
            showStatusWindow()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 협업 상태창 배치
            if let statusPanel = self.statusPanel {
                currentY -= statusPanel.frame.height
                statusPanel.setFrameOrigin(NSPoint(x: rightX - statusPanel.frame.width, y: currentY))
                currentY -= spacing
            }
            
            // 개별 채팅창 배치
            for panel in self.chatPanels.values where panel.isVisible {
                currentY -= panel.frame.height
                
                // 공간 부족 시 약간 겹치게(Cascade) 처리
                if currentY < visibleFrame.minY { currentY = visibleFrame.minY + padding }
                
                panel.setFrameOrigin(NSPoint(x: rightX - panel.frame.width, y: currentY))
                currentY -= spacing
            }
        }
    }

    // MARK: - 감정-스프라이트 상태 관리

    /// AI 응답 수신 시 호출 — 에이전트를 '말하는 중'으로 표시하고 감정 감지
    /// TTS가 끝날 때까지 말풍선 유지. 안전장치: 최대 30초 후 자동 clear
    func setAgentSpeaking(agentID: String, text: String) {
        let emotion = detectEmotion(from: text)
        DispatchQueue.main.async {
            self.speakingAgentID = agentID
            self.agentEmotions[agentID] = emotion
        }
        // 안전장치: TTS가 끝나지 않아도 최대 30초 후 자동 clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if self?.speakingAgentID == agentID {
                self?.clearAgentSpeaking(agentID: agentID)
            }
        }
    }

    /// TTS 종료 시 호출 — 해당 에이전트를 '대기 중'(.typing)으로 복원
    func clearAgentSpeaking(agentID: String) {
        DispatchQueue.main.async {
            if self.speakingAgentID == agentID {
                self.speakingAgentID = nil
            }
            self.agentEmotions[agentID] = .typing
        }
    }

    /// 텍스트 키워드 기반 감정 추론
    private func detectEmotion(from text: String) -> AnimationState {
        let t = text
        // 기쁨/긍정
        if t.contains("잘했") || t.contains("훌륭") || t.contains("완벽") || t.contains("최고") ||
           t.contains("축하") || t.contains("좋아") || t.contains("굿") || t.contains("ㅋㅋ") ||
           t.contains("👍") || t.contains("🎉") || t.contains("😊") || t.contains("🥳") {
            return .joy
        }
        // 긍정 동의
        if t.contains("맞아") || t.contains("맞습") || t.contains("동의") || t.contains("그렇죠") ||
           t.contains("물론") || t.contains("네, ") || t.contains("넵") || t.contains("오케이") ||
           t.contains("알겠") || t.contains("확인했") {
            return .agree
        }
        // 슬픔/공감
        if t.contains("안타") || t.contains("힘들") || t.contains("어렵") || t.contains("슬프") ||
           t.contains("속상") || t.contains("미안") || t.contains("죄송") || t.contains("😢") ||
           t.contains("😔") {
            return .sad
        }
        // 혼란/당황
        if t.contains("음...") || t.contains("음…") || t.contains("글쎄") || t.contains("잘 모르") ||
           t.contains("모르겠") || t.contains("애매") || t.contains("헷갈") || t.contains("?") {
            return .confused
        }
        // 인사
        if t.contains("안녕") || t.contains("반가") || t.contains("어서") || t.contains("오셨") {
            return .greeting
        }
        // 기본: 말하는 중
        return .speaking
    }

    // MARK: - LocalEventKind — 이벤트 종류와 설정 플래그를 1:1로 정확히 매핑

    private enum LocalEventKind {
        case startup   // 앱 시작
        case wake      // 잠금 해제 (didWake)
        case idle      // 15분 대기
        case sleep     // 30분 수면

        /// 해당 이벤트의 UserDefaults 활성 플래그 키
        var defaultsKey: String {
            switch self {
            case .startup: return "startupGreetingEnabled"
            case .wake:    return "wakeGreetingEnabled"
            case .idle:    return "idleGreetingEnabled"
            case .sleep:   return "sleepGreetingEnabled"
            }
        }

        /// AnimationState 변환 (CharacterDialogues 대사 선택용)
        var animationState: AnimationState {
            switch self {
            case .startup, .wake: return .greeting
            case .idle:           return .idle
            case .sleep:          return .sleeping
            }
        }
    }

    private func checkIdle() {
        let idleSeconds = Date().timeIntervalSince(lastInteractionTime)
        if idleSeconds >= 1800 && idleSeconds < 1860 {
            let fallback = ["...Zzzz...", "자고 있었어요~"]
            speakLocalEvent(text: fallback.randomElement()!, kind: .sleep)
        } else if idleSeconds >= 900 && idleSeconds < 960 {
            let fallback = ["안 안뉐하셨죠?", "졸고 있었던 거 아니에요!", "보고 싶었어요.", "계속 대기 중!"]
            speakLocalEvent(text: fallback.randomElement()!, kind: .idle)
        }
    }

    // MARK: - 시스템 이벤트 (인사말) 처리
    @objc private func handleWake() {
        let userTitle = UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"
        let fallback = ["\(userTitle), 드디어 오셨네요!", "기다리고 있었어요!",
                        "다시 작업 모드로 전환합니다!",
                        "잠금해제 소리만 기다렸다니까요, \(userTitle). 바로 일하러 가시죠!"]
        speakLocalEvent(text: fallback.randomElement()!, kind: .wake)
        Task { await LLMConfigCatalog.shared.refreshAllIfNeeded() }
    }

    private func handleStartup() {
        let userTitle = UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"
        let fallback = ["반가워요! 오늘 하루도 잘 부탁드려요.", "접속 완료! 어떤 일부터 할까요?",
                        "준비 끝!", "\(userTitle), 에이전트 가동 시작합니다!"]
        speakLocalEvent(text: fallback.randomElement()!, kind: .startup)
    }

    /// 로컬 시스템 이벤트 전용 메서드.
    /// - 채팅 로그에 절대 기록하지 않음.
    /// - 각 이벤트 종류별 UserDefaults 플래그가 false면 TTS도 실행하지 않음 (기본값 false).
    private func speakLocalEvent(text: String, kind: LocalEventKind) {
        guard UserDefaults.standard.bool(forKey: kind.defaultsKey) else {
            AppLog.info("[SystemEvent] '\(kind.defaultsKey)' 비활성 — 스킵")
            return
        }
        guard !isSilentMode else { return }
        guard let agent = activeAgents.first else { return }

        let state = kind.animationState
        let line = CharacterDialogues.randomLine(for: agent.name, state: state) ?? text
        // 채팅 로그 추가 없음 — TTS만
        setAgentSpeaking(agentID: agent.id, text: line)
        SpeechManager.shared.speak(text: line, agentID: agent.id, characterName: agent.name)
    }

    // MARK: - 팀 테이블 창 열기
    func showTeam() {
        guard teamPanel == nil else {
            teamPanel?.orderFront(nil)
            return
        }

        // 화면 하단 중앙에 기본 배치 (너비를 기존의 반으로 줄임)
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        let panelWidth: CGFloat = 460
        let panelHeight: CGFloat = 280 // 팝업 메뉴가 위로 뜰 공간을 위해 높이 확보 (160 -> 280)
        let x = (screenWidth - panelWidth) / 2
        let y: CGFloat = 60  // 화면 하단에서 60pt 위

        let panel = FloatingPanel(
            agentID: "team",
            position: NSPoint(x: x, y: y),
            size: NSSize(width: panelWidth, height: panelHeight)
        )

        // SwiftUI TeamTableView를 창에 주입
        let view = TeamTableView().environmentObject(self)
        panel.contentViewController = NSHostingController(rootView: view)

        panel.orderFront(nil)
        panel.makeKey()
        teamPanel = panel
        
        // 팀 창 띄울 때 현황 창도 함께 띄우기
        showStatusWindow()
    }

    // MARK: - 창 숨기기 / 닫기
    func hideTeam() {
        teamPanel?.close()
        teamPanel = nil
    }

    // MARK: - 위치 저장
    func savePosition() {
        teamPanel?.savePosition()
        chatPanels.values.forEach { $0.savePosition() }
    }
    
    // MARK: - 위치 초기화 (가가운 중앙으로 불러오기)
    func resetWindowPositions() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? .zero
        
        let panelWidth: CGFloat = 460
        
        // 1. 메인 팀 테이블: 화면 하단 중앙 (Dock 위)
        let teamX = visibleFrame.origin.x + (visibleFrame.width - panelWidth) / 2
        let teamY = visibleFrame.origin.y + 20
        
        teamPanel?.setFrameOrigin(NSPoint(x: teamX, y: teamY))
        teamPanel?.orderFront(nil)
        
        // 2. 협업 현황 창: 메인 창 오른쪽에 배치
        let statusX = teamX + panelWidth + 20
        let statusY = teamY
        statusPanel?.setFrameOrigin(NSPoint(x: statusX, y: statusY))
        statusPanel?.orderFront(nil)
        
        print("Window positions reset to center.")
    }

    // MARK: - 개별 채팅창 띄우기 (Singular instance)
    func showChat(for config: AgentConfig, isPersonalChat: Bool = true) {
        if let existing = chatPanels.values.first {
            existing.orderFront(nil)
            existing.makeKey()
            NotificationCenter.default.post(name: NSNotification.Name("didSelectAgentForChat"), object: nil, userInfo: ["agentID": config.id])
            return
        }

        // 팀 창 근체 위쪽에 띄우기 (간격 거의 없게)
        let teamFrame = teamPanel?.frame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = teamFrame.origin.x + 40
        let y = teamFrame.origin.y + teamFrame.height + 2

        var routedConfig = config
        routedConfig.applyDeskRouting(index: activeAgents.firstIndex(where: { $0.id == config.id }) ?? 0)

        let panel = FloatingPanel(
            agentID: "chat_single",
            position: NSPoint(x: x, y: y),
            size: NSSize(width: 600, height: 520)
        )
        panel.minSize = NSSize(width: 300, height: 480)

        let view = AgentChatView(
            config: routedConfig,
            onClose: { [weak self] in self?.hideChat(id: config.id) },
            isPersonalChat: isPersonalChat
        ).environmentObject(self)

        panel.contentViewController = NSHostingController(rootView: view)
        panel.orderFront(nil)
        panel.makeKey()
        chatPanels["chat_single"] = panel
    }
    
    // MARK: - 개별 채팅창 닫기
    func hideChat(id: String) {
        chatPanels.values.forEach { $0.close() }
        chatPanels.removeAll()
    }
    
    // MARK: - 에이전트 교체 창 띄우기
    func showSwapWindow(replaceIndex: Int = 0) {
        if swapPanel != nil {
            swapPanel?.orderFront(nil)
            swapPanel?.makeKey()
            return
        }
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let width: CGFloat = 800
        let height: CGFloat = 580
        let panel = FloatingPanel(
            agentID: "swap_window",
            position: NSPoint(
                x: screenRect.midX - (width / 2),
                y: screenRect.midY - (height / 2)
            ),
            size: NSSize(width: width, height: height)
        )
        // 교체 창은 일반 창처럼 상호작용해야 하므로 키 윈도우 지원
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        
        let view = AgentSwapView(replaceIndex: replaceIndex, onClose: { [weak self] in
            self?.hideSwapWindow()
        }).environmentObject(self)
        
        panel.contentViewController = NSHostingController(rootView: view)
        panel.orderFront(nil)
        panel.makeKey()
        swapPanel = panel
    }
    
    func hideSwapWindow() {
        swapPanel?.close()
        swapPanel = nil
    }
    
    // MARK: - 에이전트 스왑 로직 (순서 변경 포함)
    func swapAgent(at index: Int, with newAgent: AgentConfig) {
        guard index >= 0 && index < activeAgents.count else { return }
        var routedAgent = newAgent
        routedAgent.applyDeskRouting(index: index)

        // 만약 선택한 에이전트가 이미 테이블의 다른 자리에 있다면, 둘의 자리를 맞바꿈 (Swap)
        if let existingIndex = activeAgents.firstIndex(where: { $0.id == routedAgent.id }) {
            let temp = activeAgents[index]
            activeAgents[index] = activeAgents[existingIndex]
            activeAgents[existingIndex] = temp
        } else {
            // 새 에이전트로 교체
            activeAgents[index] = routedAgent
        }

        // 교체 TTS — 동기적 flush 후 즉시 실행 (딜레이 없음)
        if !isSilentMode {
            SpeechManager.shared.stopSpeaking()
            let greeting = swapGreeting(for: routedAgent.name)
            SpeechManager.shared.speak(text: greeting, agentID: routedAgent.id, characterName: routedAgent.name)
        }
    }

    // MARK: - 팀 리더 관리

    func teamLeader(for roomID: UUID? = nil) -> AgentConfig? {
        let targetID = roomID ?? currentRoomID
        guard let rid = targetID,
              let room = rooms.first(where: { $0.id == rid }),
              let leaderID = room.leaderAgentID,
              let leader = activeAgents.first(where: { $0.id == leaderID }) else {
            return nil
        }
        return leader
    }

    func fallbackTeamLeader(for roomID: UUID? = nil) -> AgentConfig? {
        teamLeader(for: roomID) ?? activeAgents.first
    }

    func setTeamLeader(agentID: String, roomID: UUID? = nil) {
        let targetID = roomID ?? currentRoomID
        guard activeAgents.contains(where: { $0.id == agentID }),
              let rid = targetID,
              let index = rooms.firstIndex(where: { $0.id == rid }) else { return }
        rooms[index].leaderAgentID = agentID
    }

    struct AgentMentionResolution {
        let mentionedAgent: AgentConfig
        let activeAgent: AgentConfig?

        var isActive: Bool { activeAgent != nil }
    }

    func resolveMentionedAgent(in message: String) -> AgentMentionResolution? {
        let normalizedMessage = message
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        let candidates = allAvailableAgents
            .sorted { $0.name.count > $1.name.count }

        guard let mentioned = candidates.first(where: { agent in
            normalizedMessage.contains(agent.name.lowercased())
        }) else {
            return nil
        }

        let active = activeAgents.first(where: { $0.id == mentioned.id })
        return AgentMentionResolution(mentionedAgent: mentioned, activeAgent: active)
    }

    /// 캐릭터별 교체 인사 — 성격 반영, 짧고 빠르게
    private func swapGreeting(for name: String) -> String {
        let greetings: [String: [String]] = [
            "레오": ["전략가 레오, 투입.", "레오 출근.", "분석 시작.", "준비 완료.", "배치 확인."],
            "루나": ["안녕! 보고싶었지?!", "루나 등장!", "텐션 업!", "나왔다!", "기다렸지?!"],
            "치코": ["반가워요!", "이쁘게 해줄게!", "디자인 시작!", "안녕!", "기대해요!"],
            "렉스": ["...왔습니다.", "...배치 완료.", "...시작하죠.", "...렉스입니다.", "...조용히 하겠습니다."],
            "케이": ["보안 점검.", "케이 투입.", "감시 시작.", "이상 없음.", "배치 확인."],
            "모코": ["일정 확인!", "모코 출근!", "시작합시다.", "준비됐습니다.", "체크리스트!"],
            "핀": ["핀 등장!", "그려볼까!", "안녕안녕!", "준비 끝!", "시작이다!"],
            "래키": ["래키 왔어!", "달려볼까!", "안녕!", "출발!", "기대돼!"],
            "폴라": ["폴라입니다.", "시작하죠.", "안녕.", "준비됐어요.", "배치 완료."],
            "몽몽": ["몽몽 왔어!", "안녕!", "놀자!", "준비 끝!", "기다렸어!"],
            "올리버": ["올리버 출근.", "안녕하세요.", "시작합시다.", "준비됐습니다.", "잘 부탁해요."],
        ]
        let options = greetings[name] ?? ["안녕!"]
        return options.randomElement() ?? "안녕!"
    }
    
    // MARK: - 에이전트 스택/상태 창 띄우기
    func showStatusWindow() {
        if statusPanel != nil {
            statusPanel?.orderFront(nil)
            return
        }
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let width: CGFloat = 300
        let height: CGFloat = 450
        
        // 화면 중앙 오른쪽에 배치
        let panel = FloatingPanel(
            agentID: "status_window",
            position: NSPoint(
                x: screenRect.maxX - width - 40,
                y: screenRect.midY - (height / 2)
            ),
            size: NSSize(width: width, height: height)
        )
        let view = TeamStatusView().environmentObject(self)
        panel.contentViewController = NSHostingController(rootView: view)

        panel.orderFront(nil)
        statusPanel = panel
    }
    
    func hideStatusWindow() {
        statusPanel?.close()
        statusPanel = nil
    }
    
    // MARK: - 개별 에이전트 커스텀 성격 설정 창
    func showAgentSettingsWindow(for config: AgentConfig) {
        if agentSettingsPanel != nil {
            agentSettingsPanel?.orderFront(nil)
            agentSettingsPanel?.makeKey()
            return
        }
        
        let width: CGFloat = 360
        let height: CGFloat = 520
        // 팀 창 근처 적절한 위치에 띄움
        let teamFrame = teamPanel?.frame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = teamFrame.origin.x + (teamFrame.width / 2) - (width / 2)
        let y = teamFrame.origin.y + teamFrame.height + 40
        
        let panel = FloatingPanel(
            agentID: "agent_settings_\(config.id)",
            position: NSPoint(x: x, y: y),
            size: NSSize(width: width, height: height)
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        
        let view = AgentSettingsView(config: config, onClose: { [weak self] in
            self?.hideAgentSettingsWindow()
        }).environmentObject(self)
        
        panel.contentViewController = NSHostingController(rootView: view)
        panel.orderFront(nil)
        panel.makeKey()
        agentSettingsPanel = panel
    }
    
    func hideAgentSettingsWindow() {
        agentSettingsPanel?.close()
        agentSettingsPanel = nil
    }
    
    // MARK: - 환경 설정 창 띄우기 (API 키 등)
    func showSettingsWindow() {
        if settingsPanel != nil {
            settingsPanel?.orderFront(nil)
            settingsPanel?.makeKey()
            return
        }
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let width: CGFloat = 460
        let height: CGFloat = 520
        
        let panel = FloatingPanel(
            agentID: "settings_window",
            position: NSPoint(
                x: screenRect.midX - (width / 2),
                y: screenRect.midY - (height / 2)
            ),
            size: NSSize(width: width, height: height)
        )
        // 설정 창은 일반 창처럼 상호작용해야 하므로 키 윈도우 지원
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        
        let view = SettingsView()
            .environmentObject(self)
        
        panel.contentViewController = NSHostingController(rootView: view)
        panel.orderFront(nil)
        panel.makeKey()
        settingsPanel = panel
    }
    
    func hideSettingsWindow() {
        settingsPanel?.close()
        settingsPanel = nil
    }

    // MARK: - 창 크기 동적 조절 (SwiftUI에서 호출)
    func updateStatusWindowSize(width: CGFloat, height: CGFloat) {
        guard let panel = statusPanel else { return }
        var frame = panel.frame
        let heightDiff = height - frame.size.height
        frame.origin.y -= heightDiff
        frame.size = NSSize(width: width, height: height)
        panel.setFrame(frame, display: true, animate: true)
        panel.savePosition()
    }
    
    func updateChatWindowWidth(id: String, width: CGFloat) {
        guard let panel = chatPanels["chat_single"] else { return }
        var frame = panel.frame
        frame.size.width = width
        panel.setFrame(frame, display: true, animate: true)
    }

    func updateChatWindowSize(id: String, width: CGFloat, height: CGFloat, minSize: NSSize? = nil) {
        guard let panel = chatPanels["chat_single"] else { return }
        if let minSize { panel.minSize = minSize }
        var frame = panel.frame
        // y 좌표를 조정해서 창이 위로 줄어들지 않고 아래쪽이 고정되게
        let heightDiff = height - frame.size.height
        frame.origin.y -= heightDiff
        frame.size = NSSize(width: width, height: height)
        panel.setFrame(frame, display: true, animate: true)
    }

    func savedChatWindowSize() -> NSSize? {
        let width = UserDefaults.standard.double(forKey: "chat_single_w")
        let height = UserDefaults.standard.double(forKey: "chat_single_h")
        guard width >= 300, height >= 480 else { return nil }
        return NSSize(width: width, height: height)
    }

    // MARK: - 채팅 로그 추가

    /// roomID 명시 필수형 — 비동기 Task 안에서는 반드시 이것을 사용한다.
    /// 발신 시점의 roomID를 캡처해서 전달해야 race condition / room 오염을 막는다.
    func addChatLog(
        roomID: UUID,
        agentID: String,
        agentName: String,
        text: String,
        isUser: Bool,
        isSystem: Bool = false,
        sources: [SourceReference] = [],
        skillID: String? = nil
    ) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        let newLog = ChatLog(id: UUID(), agentID: agentID, agentName: agentName,
                             text: text, isUser: isUser, timestamp: Date(), isSystem: isSystem, sources: sources, skillID: skillID)
        rooms[index].messages.append(newLog)
    }

    /// ⚠️ currentRoomID를 내부에서 읽어 비동기 컨텍스트에서 race condition 위험이 있습니다.
    /// 비동기 Task 내부에서는 addChatLog(roomID:...) 명시형을 사용하세요.
    @available(*, deprecated, message: "Use addChatLog(roomID:agentID:agentName:text:isUser:) in async contexts to avoid room contamination")
    func addChatLog(
        agentID: String,
        agentName: String,
        text: String,
        isUser: Bool,
        roomID: UUID? = nil,
        isSystem: Bool = false,
        sources: [SourceReference] = [],
        skillID: String? = nil
    ) {
        let rid = roomID ?? currentRoomID
        guard let rid else { return }
        addChatLog(roomID: rid, agentID: agentID, agentName: agentName,
                   text: text, isUser: isUser, isSystem: isSystem, sources: sources, skillID: skillID)
    }

    func replaceMessages(roomID: UUID, with messages: [ChatLog]) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].messages = messages
    }

    func clearMessages(roomID: UUID) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].messages.removeAll()
    }

    func addKeyFact(_ fact: String) {
        let cleaned = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if !keyFacts.contains(cleaned) {
            keyFacts.append(cleaned)
        }
    }

    func forgetKeyFact(matching query: String) -> Int {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return 0 }
        let before = keyFacts.count
        keyFacts.removeAll { $0.lowercased().contains(cleaned) }
        return before - keyFacts.count
    }

    func clearKeyFacts() {
        keyFacts.removeAll()
    }

    // MARK: - 스케줄 업무

    @discardableResult
    func addAutomationTask(prompt: String, nextRunAt: Date, repeatInterval: TimeInterval? = nil, roomID: UUID? = nil, assignedAgentID: String? = nil) -> AutomationTask {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = String(trimmed.prefix(28))
        let task = AutomationTask(
            id: UUID(),
            title: title.isEmpty ? "스케줄 업무" : title,
            prompt: trimmed,
            nextRunAt: nextRunAt,
            repeatInterval: repeatInterval,
            roomID: roomID ?? currentRoomID,
            assignedAgentID: assignedAgentID,
            isEnabled: true,
            createdAt: Date(),
            lastRunAt: nil
        )
        automationTasks.append(task)
        return task
    }

    func cancelAutomationTask(id: UUID) {
        automationTasks.removeAll { $0.id == id }
    }

    func cancelAutomationTask(displayIndex: Int) -> Bool {
        let sorted = automationTasks.sorted { $0.nextRunAt < $1.nextRunAt }
        guard displayIndex > 0, displayIndex <= sorted.count else { return false }
        cancelAutomationTask(id: sorted[displayIndex - 1].id)
        return true
    }

    /// /edit-task 명령 처리.
    /// - idPrefix: 작업 UUID 앞 6자 이상
    /// - options: "HH:MM" | "--disable" | "--enable" | "--approval on|off"
    /// - Returns: 사용자에게 보여줄 결과 메시지
    func editAutomationTask(idPrefix: String, option: String) -> String {
        let prefix = idPrefix.lowercased()
        guard let idx = automationTasks.firstIndex(where: { $0.id.uuidString.lowercased().hasPrefix(prefix) }) else {
            return "작업 ID '\(idPrefix)'를 찾지 못했습니다. /tasks 로 목록을 확인하세요."
        }
        let opt = option.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if opt == "--disable" {
            automationTasks[idx].isEnabled = false
            return "'\(automationTasks[idx].title)' 작업을 비활성화했습니다."
        } else if opt == "--enable" {
            automationTasks[idx].isEnabled = true
            return "'\(automationTasks[idx].title)' 작업을 활성화했습니다."
        } else if opt == "--approval on" {
            automationTasks[idx].requiresApproval = true
            return "'\(automationTasks[idx].title)' 작업에 실행 전 승인을 설정했습니다."
        } else if opt == "--approval off" {
            automationTasks[idx].requiresApproval = false
            return "'\(automationTasks[idx].title)' 작업의 승인 요건을 해제했습니다."
        } else {
            // HH:MM 시간 변경 파싱
            let timeParts = opt.split(separator: ":")
            guard timeParts.count == 2,
                  let h = Int(timeParts[0]), let m = Int(timeParts[1]),
                  (0...23).contains(h), (0...59).contains(m) else {
                return "인식할 수 없는 옵션입니다. 예: /edit-task \(idPrefix) 09:30 | --disable | --enable | --approval on"
            }
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: automationTasks[idx].nextRunAt)
            comps.hour = h; comps.minute = m; comps.second = 0
            if let newDate = cal.date(from: comps) {
                automationTasks[idx].nextRunAt = newDate > Date() ? newDate : cal.date(byAdding: .day, value: 1, to: newDate) ?? newDate
            }
            return "'\(automationTasks[idx].title)' 다음 실행 시간을 \(String(format: "%02d:%02d", h, m))로 변경했습니다."
        }
    }

    // 승인 대기 중인 task ID Set
    @Published var pendingApprovalTaskIDs: Set<UUID> = []

    /// 승인 대기 중인 task를 승인하여 즉시 실행
    func approveAutomationTask(id: UUID) {
        pendingApprovalTaskIDs.remove(id)
        guard let task = automationTasks.first(where: { $0.id == id }) else { return }
        executeApprovedTask(task)
    }

    /// 승인 대기 중인 task를 이번 회차 건너뜀 (다음 실행 시각으로 미룸)
    func skipAutomationTask(id: UUID) {
        pendingApprovalTaskIDs.remove(id)
        guard let idx = automationTasks.firstIndex(where: { $0.id == id }) else { return }
        if let interval = automationTasks[idx].repeatInterval {
            automationTasks[idx].nextRunAt = Date().addingTimeInterval(interval)
        } else {
            automationTasks.remove(at: idx)
        }
        if let rid = currentRoomID {
            addChatLog(roomID: rid, agentID: "system", agentName: "스케줄",
                       text: "⏭️ '\(automationTasks.first(where: { $0.id == id })?.title ?? "작업")'을 건너뜠습니다.",
                       isUser: false)
        }
    }

    private func executeApprovedTask(_ task: AutomationTask) {
        let targetRoomID = task.roomID ?? currentRoomID
        Task { @MainActor in
            let substitute = self.activeAgents.first(where: { $0.id == task.assignedAgentID })
                ?? self.teamLeader() ?? self.activeAgents.first
            if let agent = substitute {
                _ = await ConversationMemory.handleChatCommand(task.prompt, roomID: targetRoomID, manager: self, currentAgent: agent)
            }
        }
    }

    private func runDueAutomationTasks() {
        let now = Date()
        let dueTasks = automationTasks.filter { $0.isEnabled && $0.nextRunAt <= now }
        guard !dueTasks.isEmpty else { return }

        for task in dueTasks {
            guard let index = automationTasks.firstIndex(where: { $0.id == task.id }) else { continue }

            // Destructive action policy check
            let (allowed, reason) = AutomationPolicy.isAllowed(task.prompt)
            guard allowed else {
                AppLog.warning("[Schedule] 차단됨: \(task.title) — \(reason ?? "")")
                if let rid = task.roomID ?? currentRoomID {
                    addChatLog(roomID: rid, agentID: "system", agentName: "스케줄",
                               text: "⚠️ 스케줄 업무 차단: \(reason ?? "정책 위반")",
                               isUser: false)
                }
                continue
            }

            let targetRoomID = task.roomID ?? currentRoomID

            // 승인 대기 처리: requiresApproval=true이고 아직 대기 중이 아니면 승인 요청
            if task.requiresApproval && !pendingApprovalTaskIDs.contains(task.id) {
                pendingApprovalTaskIDs.insert(task.id)
                let shortId = String(task.id.uuidString.prefix(6))
                if let rid = targetRoomID {
                    addChatLog(roomID: rid, agentID: "system", agentName: "스케줄",
                               text: "✋ 스케줄 업무 승인 요청: \"\(task.title)\"\n/approve \(shortId) — 승인 실행\n/skip \(shortId) — 이번 회차 건너뜀\n(2분 내 응답 없으면 자동 실행)",
                               isUser: false)
                }
                // 2분 타임아웃 후 자동 실행
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 120_000_000_000)
                    guard let self, self.pendingApprovalTaskIDs.contains(task.id) else { return }
                    self.pendingApprovalTaskIDs.remove(task.id)
                    self.executeApprovedTask(task)
                }
                continue
            }

            automationTasks[index].lastRunAt = now
            if let interval = task.repeatInterval {
                automationTasks[index].nextRunAt = now.addingTimeInterval(interval)
            } else {
                automationTasks.remove(at: index)
            }

            if let rid = targetRoomID {
                addChatLog(roomID: rid, agentID: "system", agentName: "스케줄",
                           text: "스케줄 업무 실행: \(task.prompt)",
                           isUser: false)
            }

            Task {
                let assignedAgent = task.assignedAgentID.flatMap { assignedID in
                    allAvailableAgents.first(where: { $0.id == assignedID })
                }
                let activeAssignee = task.assignedAgentID.flatMap { assignedID in
                    activeAgents.first(where: { $0.id == assignedID })
                }
                let substitute = activeAssignee ?? fallbackTeamLeader(for: targetRoomID)

                if let assignedAgent, activeAssignee == nil, let substitute, let rid = targetRoomID {
                    addChatLog(roomID: rid, agentID: substitute.id, agentName: substitute.name,
                               text: "\(assignedAgent.name)은 지금 팀에 없어서 제가 대신 할게요.",
                               isUser: false)
                }

                if task.prompt.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
                    _ = await ConversationMemory.handleChatCommand(task.prompt, roomID: targetRoomID, manager: self, currentAgent: substitute)
                } else if let roomID = targetRoomID {
                    let scheduledPrompt: String
                    if let activeAssignee {
                        scheduledPrompt = "\(activeAssignee.name)가 담당해서 수행해줘. \(task.prompt)"
                    } else if let substitute {
                        scheduledPrompt = "\(substitute.name)가 담당해서 수행해줘. \(task.prompt)"
                    } else {
                        scheduledPrompt = task.prompt
                    }
                    await TeamOrchestrator.shared.runTeamDiscussion(
                        userMessage: scheduledPrompt,
                        roomID: roomID,
                        manager: self
                    )
                }
            }
        }
    }

    // MARK: - 방 생성 / 이름 변경 / 삭제
    func createRoom(name: String) {
        let newRoom = ChatRoom(id: UUID(), name: name,
            messages: [], agentIDs: ["team_all"], createdAt: Date())
        rooms.append(newRoom)
        currentRoomID = newRoom.id
    }

    /// 특정 에이전트 전용 방 생성
    func createAgentRoom(name: String, agentID: String) {
        let newRoom = ChatRoom(id: UUID(), name: name,
            messages: [], agentIDs: [agentID], createdAt: Date())
        rooms.append(newRoom)
    }

    func renameRoom(id: UUID, newName: String) {
        guard let index = rooms.firstIndex(where: { $0.id == id }) else { return }
        rooms[index].name = newName
    }

    func deleteRoom(id: UUID) {
        rooms.removeAll { $0.id == id }
        if currentRoomID == id { currentRoomID = rooms.first?.id }
    }

    func deleteMessage(roomID: UUID, messageID: UUID) {
        guard let idx = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[idx].messages.removeAll { $0.id == messageID }
    }

    // MARK: - 팀 전체 채팅창 띄우기 (프로젝트별)
    func showProjectChat(roomID: UUID) {
        currentRoomID = roomID
        showChat(for: Self.teamRepresentative, isPersonalChat: false)
    }

    // MARK: - 채팅 데이터 영속화
    private func saveRooms() {
        if let encoded = try? JSONEncoder().encode(rooms) {
            UserDefaults.standard.set(encoded, forKey: "myteam_rooms")
        }
    }

    private func loadRooms() {
        if let data = UserDefaults.standard.data(forKey: "myteam_rooms"),
           let decoded = try? JSONDecoder().decode([ChatRoom].self, from: data) {
            rooms = decoded
        }
    }

    // MARK: - RecentArtifactIndex Facade API

    @MainActor
    func addRecentArtifactIndexEntry(_ entry: RecentArtifactIndexEntry) {
        roomRuntimeStore.recentArtifactIndex.add(entry)
    }

    @MainActor
    func recentArtifactIndexEntries(for roomID: UUID) -> [RecentArtifactIndexEntry] {
        roomRuntimeStore.recentArtifactIndex.recentArtifacts(for: roomID)
    }

    @MainActor
    func recentArtifactIndexEntry(
        artifactID: String,
        roomID: UUID
    ) -> RecentArtifactIndexEntry? {
        roomRuntimeStore.recentArtifactIndex.entry(for: artifactID, roomID: roomID)
    }
}
