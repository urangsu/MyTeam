import AppKit
import SwiftUI
import Foundation
import Combine

// MARK: - AgentWindowManager
// 팀 테이블 창 1개를 생성하고, 4명의 에이전트를 그 안에 표시합니다.
class AgentWindowManager: ObservableObject {

    static let shared = AgentWindowManager()

    struct AgentConfig: Identifiable {
        let id: String
        let name: String
        let role: String         // 예: "프로젝트 매니저" (UI 상단용)
        let emoji: String        // 평상시 이모지
        let color: Color
        let isPremium: Bool      // 교체 창 UI용 (무료/프리미엄 표시)
        var status: String       // 현재 상태 (예: "일하는 중", "휴식 중")

        // ── 개인별 드래그 반응 ──
        let dragEmoji: String    // 드래그 중 이모지
        let dragRotation: Double // 기울기 각도
        let dragSoundName: String
        let dropSoundName: String
    }

    // ── 구매 가능하거나 보유한 전체 에이전트 목록 (DB/API 연동 전 임시 데이터) ──
    let allAvailableAgents: [AgentConfig] = [
        AgentConfig(id: "agent_1", name: "맥스", role: "프로젝트 매니저", emoji: "🐕", color: .blue, isPremium: false, status: "팀 전략 수립 중", dragEmoji: "😱", dragRotation: -14, dragSoundName: "Pop", dropSoundName: "Funk"),
        AgentConfig(id: "agent_2", name: "올리버", role: "백엔드 개발자", emoji: "🐷", color: .purple, isPremium: false, status: "API 설계 및 서버 구축 중", dragEmoji: "😵", dragRotation: 10, dragSoundName: "Blow", dropSoundName: "Pop"),
        AgentConfig(id: "agent_3", name: "펭", role: "UI/UX 디자이너", emoji: "🐧", color: .green, isPremium: true, status: "UI 프로토타입 디자인 중", dragEmoji: "🤯", dragRotation: -8, dragSoundName: "Morse", dropSoundName: "Funk"),
        AgentConfig(id: "agent_4", name: "루나", role: "프론트엔드 개발자", emoji: "🐱", color: .orange, isPremium: true, status: "SwiftUI 컴포넌트 개발 중", dragEmoji: "😤", dragRotation: 12, dragSoundName: "Ping", dropSoundName: "Pop"),
        AgentConfig(id: "agent_5", name: "토비", role: "QA 엔지니어", emoji: "🐰", color: .gray, isPremium: true, status: "단위 테스트 코드 작성 중", dragEmoji: "😵‍💫", dragRotation: -5, dragSoundName: "Pop", dropSoundName: "Pop"),
        AgentConfig(id: "agent_6", name: "레오", role: "데이터 분석가", emoji: "🦊", color: .red, isPremium: true, status: "사용자 로그 데이터 분석 중", dragEmoji: "🤔", dragRotation: 15, dragSoundName: "Blow", dropSoundName: "Funk"),
        AgentConfig(id: "agent_7", name: "베어", role: "DevOps 엔지니어", emoji: "🐻", color: .brown, isPremium: true, status: "CI/CD 파이프라인 구성 중", dragEmoji: "😴", dragRotation: -10, dragSoundName: "Morse", dropSoundName: "Pop"),
        AgentConfig(id: "agent_8", name: "밤비", role: "머신러닝 엔지니어", emoji: "🐼", color: .black, isPremium: true, status: "추천 알고리즘 모델 학습 중", dragEmoji: "😲", dragRotation: 8, dragSoundName: "Ping", dropSoundName: "Funk")
    ]
    
    // ── 전역 설정 ──
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
    @AppStorage("isVoiceMode") var isVoiceMode: Bool = true
    @AppStorage("isSilentMode") var isSilentMode: Bool = false

    // ── 팀 전체 채팅 로그 (히스토리) ──
    struct ChatLog: Identifiable, Codable {
        let id: UUID
        let agentID: String
        let agentName: String
        let text: String
        let isUser: Bool
        let timestamp: Date
    }
    @Published var teamChatLogs: [ChatLog] = []

    // 팀의 현재 큰 업무
    @Published var currentMainTask: String = "AI 팀 프로젝트 매니징 및 고도화"
    
    // 팀 전체 설정 — 현재 화면에 나와있는 4명의 에이전트 (순서 변경 및 교체 가능)
    @Published var activeAgents: [AgentConfig]
    
    // 팀 테이블 창 (하나)
    private var teamPanel: FloatingPanel?
    
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
        // 초기 4명 세팅
        activeAgents = Array(allAvailableAgents.prefix(4))
        
        // 잠금 해제 / 잠자기 해제 감지
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        
        // 앱 최초 시작 인사말
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.handleStartup()
        }
        
        // 아이들 감지 타이머 (1분마다 체크)
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }
    
    // 마지막 상호작용 시간 갱신
    func updateInteractionTime() {
        lastInteractionTime = Date()
    }
    
    private func checkIdle() {
        let idleSeconds = Date().timeIntervalSince(lastInteractionTime)
        // 15분(900초) 이상 상호작용이 없으면 아이들 인사 전송
        if idleSeconds >= 900 && idleSeconds < 960 { // 딱 한 번 발생하도록 범위 지정
            let idleGreetings = ["안 안뇽하셨죠?", "졸고 있었던 거 아니에요!", "보고 싶었어요.", "계속 대기 중!"]
            WebSocketClient.shared.sendSystemEvent(eventType: "idle", baseGreeting: idleGreetings.randomElement()!)
        }
    }

    // MARK: - 시스템 이벤트 (인사말) 처리
    @objc private func handleWake() {
        let wakeGreetings = [
            "사용자님, 드디어 오셨네요!",
            "기다리고 있었어요!",
            "다시 작업 모드로 전환합니다!",
            "잠금 풀리는 소리만 기다렸다니까요, 사용자님. 바로 일하러 가시죠!",
            "오, 사용자님! 드디어 돌아오셨네요? 자리는 제가 잘 지키고 있었어요!"
        ]
        if let greeting = wakeGreetings.randomElement() {
            WebSocketClient.shared.sendSystemEvent(eventType: "wake", baseGreeting: greeting)
        }
    }
    
    private func handleStartup() {
        print("[DEBUG] handleStartup() called, WebSocket connected: \(WebSocketClient.shared.isConnected)")
        let startupGreetings = [
            "반가워요! 오늘 하루도 잘 부탁드려요.",
            "접속 완료! 어떤 일부터 할까요?",
            "준비 끝!",
            "사용자님, 안녕하세요! 오늘 팀원들 다 모였는데, 바로 시작할까요?",
            "사용자님, 에이전트 가동 시작합니다!"
        ]
        if let greeting = startupGreetings.randomElement() {
            WebSocketClient.shared.sendSystemEvent(eventType: "startup", baseGreeting: greeting)
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

    // MARK: - 개별 채팅창 띄우기
    func showChat(for config: AgentConfig) {
        if let existing = chatPanels[config.id] {
            existing.orderFront(nil)
            existing.makeKey()
            return
        }
        
        // 팀 창 근처 위쪽에 띄우기 (간격 거의 없게)
        let teamFrame = teamPanel?.frame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = teamFrame.origin.x + 40
        let y = teamFrame.origin.y + teamFrame.height + 2 // 대화창과 0.2 차이나게 밀착
        
        let panel = FloatingPanel(
            agentID: "chat_\(config.id)",
            position: NSPoint(x: x, y: y),
            size: NSSize(width: 380, height: 460) // 채팅창용 크기
        )
        
        let view = AgentChatView(config: config, onClose: { [weak self] in
            self?.hideChat(id: config.id)
        }).environmentObject(self)
        
        panel.contentViewController = NSHostingController(rootView: view)
        panel.orderFront(nil)
        panel.makeKey()
        chatPanels[config.id] = panel
    }
    
    // MARK: - 개별 채팅창 닫기
    func hideChat(id: String) {
        chatPanels[id]?.close()
        chatPanels.removeValue(forKey: id)
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
        
        let width: CGFloat = 320
        let height: CGFloat = 360
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
}
