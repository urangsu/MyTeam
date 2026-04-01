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
    @AppStorage("isSilentMode") var isSilentMode: Bool = false
    @AppStorage("userLocation") var userLocation: String = "전남 광양"

    // ── 방 목록 (UserDefaults 영속화) ──
    @Published var rooms: [ChatRoom] = [] {
        didSet { saveRooms() }
    }
    @Published var currentRoomID: UUID?

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
    
    // ── 지능형 기억 보호 (Key Fact Buffer) ──
    @AppStorage("keyFacts") private var keyFactsData: Data = Data()
    @Published var keyFacts: [String] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(keyFacts) {
                keyFactsData = data
            }
        }
    }
    
    var persistentContext: String {
        guard !keyFacts.isEmpty else { return "" }
        return "\n[기억해야 할 핵심 정보]\n" + keyFacts.map { "- \($0)" }.joined(separator: "\n") + "\n"
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

    private init() {
        activeAgents = Array(allAvailableAgents.prefix(4))

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
        
        // Key Facts 복구
        if let decoded = try? JSONDecoder().decode([String].self, from: keyFactsData) {
            keyFacts = decoded
        }

        // 잠금 해제 / 잠자기 해제 감지
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        // 앱 최초 시작 인사말
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.handleStartup() }

        // 아이들 감지 타이머 (1분마다 체크)
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkIdle()
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
        if statusPanel == nil || !(statusPanel!.isVisible) {
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
    func setAgentSpeaking(agentID: String, text: String) {
        let emotion = detectEmotion(from: text)
        DispatchQueue.main.async {
            self.speakingAgentID = agentID
            self.agentEmotions[agentID] = emotion
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

    private func checkIdle() {
        let idleSeconds = Date().timeIntervalSince(lastInteractionTime)
        if idleSeconds >= 1800 && idleSeconds < 1860 {
            // 30분 이상 → 수면 대사
            let fallback = ["...Zzzz...", "자고 있었어요~"]
            speakLocalEvent(text: fallback.randomElement()!, state: .sleeping, isSystem: true)
        } else if idleSeconds >= 900 && idleSeconds < 960 {
            // 15분 → 대기 대사
            let fallback = ["안 안뉐하셨죠?", "졸고 있었던 거 아니에요!", "보고 싶었어요.", "계속 대기 중!"]
            speakLocalEvent(text: fallback.randomElement()!, state: .idle, isSystem: true)
        }
    }

    // MARK: - 시스템 이벤트 (인사말) 처리
    @objc private func handleWake() {
        let userTitle = UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"
        let fallback = ["\(userTitle), 드디어 오셨네요!", "기다리고 있었어요!",
                        "다시 작업 모드로 전환합니다!",
                        "잠금해제 소리만 기다렸다니까요, \(userTitle). 바로 일하러 가시죠!"]
        speakLocalEvent(text: fallback.randomElement()!, state: .greeting, isSystem: true)
    }

    private func handleStartup() {
        let userTitle = UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"
        let fallback = ["반가워요! 오늘 하루도 잘 부탁드려요.", "접속 완료! 어떤 일부터 할까요?",
                        "준비 끝!", "\(userTitle), 에이전트 가동 시작합니다!"]
        speakLocalEvent(text: fallback.randomElement()!, state: .greeting, isSystem: true)
    }

    /// 로컬 시스템 이벤트: 랜덤 에이전트가 채팅에 기록 + TTS 재생
    /// state가 지정되면 캐릭터별 고유 대사를 우선 사용하고, 없으면 text 폴백
    private func speakLocalEvent(text: String, state: AnimationState? = nil, isSystem: Bool = false) {
        let agent = activeAgents.randomElement() ?? activeAgents[0]
        let line: String
        if let state, let charLine = CharacterDialogues.randomLine(for: agent.name, state: state) {
            line = charLine
        } else {
            line = text
        }
        addChatLog(agentID: agent.id, agentName: agent.name, text: line, isUser: false, isSystem: isSystem)
        if !isSilentMode {
            setAgentSpeaking(agentID: agent.id, text: line)
            SpeechManager.shared.speak(text: line, agentID: agent.id, characterName: agent.name)
        }
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
            updateChatWindowWidth(id: config.id, width: 600)
            NotificationCenter.default.post(name: NSNotification.Name("didSelectAgentForChat"), object: nil, userInfo: ["agentID": config.id])
            return
        }

        // 팀 창 근체 위쪽에 띄우기 (간격 거의 없게)
        let teamFrame = teamPanel?.frame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = teamFrame.origin.x + 40
        let y = teamFrame.origin.y + teamFrame.height + 2

        let panel = FloatingPanel(
            agentID: "chat_single",
            position: NSPoint(x: x, y: y),
            size: NSSize(width: 600, height: 520)
        )
        panel.minSize = NSSize(width: 300, height: 480)

        let view = AgentChatView(
            config: config,
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
        
        // 만약 선택한 에이전트가 이미 테이블의 다른 자리에 있다면, 둘의 자리를 맞바꿈 (Swap)
        if let existingIndex = activeAgents.firstIndex(where: { $0.id == newAgent.id }) {
            let temp = activeAgents[index]
            activeAgents[index] = activeAgents[existingIndex]
            activeAgents[existingIndex] = temp
        } else {
            // 새 에이전트로 교체
            activeAgents[index] = newAgent
        }
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
        // 현황창은 드래그로 위치 이동 가능하게 설정
        panel.isMovableByWindowBackground = true
        
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
        
        let view = SettingsView(onClose: { [weak self] in
            self?.hideSettingsWindow()
        }).environmentObject(self)
        
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
    func updateStatusWindowWidth(_ width: CGFloat) {
        guard let panel = teamPanel else { return }
        var frame = panel.frame
        _ = frame.size.width
        // 오른쪽으로 늘어 나도록 처리 (x는 유지)
        frame.size.width = width
        // frame.origin.x = frame.origin.x - (width - oldWidth) // 왼쪽으로 늘리려면 이 코드가 필요하지만, iMessage는 오른쪽으로 늘어남

        
        panel.setFrame(frame, display: true, animate: true)
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

    // MARK: - 채팅 로그 추가 (현재 방에 저장)
    func addChatLog(agentID: String, agentName: String, text: String, isUser: Bool, roomID: UUID? = nil, isSystem: Bool = false) {
        let targetID = roomID ?? currentRoomID
        guard let rid = targetID,
              let index = rooms.firstIndex(where: { $0.id == rid }) else { return }
        let newLog = ChatLog(id: UUID(), agentID: agentID, agentName: agentName,
                             text: text, isUser: isUser, timestamp: Date(), isSystem: isSystem)
        rooms[index].messages.append(newLog)
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
}
