import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - TeamStatusView
// 고도화: 팀 전체 채팅방(Logs) + 사운드/무음 모드 토글 + 다크모드
struct TeamStatusView: View {
    @EnvironmentObject var manager: AgentWindowManager
    @ObservedObject private var chainRunStore = ChainRunStore.shared
    @State private var isCollapsed = false
    @State private var selectedTab: Int = 0
    @State private var isDeleteMode = false
    @State private var roomToDelete: AgentWindowManager.ChatRoom? = nil
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var roomToRename: AgentWindowManager.ChatRoom? = nil
    
    @State private var inputText: String = ""
    @State private var pendingAttachments: [ChatAttachment] = []
    @State private var attachmentError: String? = nil
    @State private var isTargetedForDrop: Bool = false
    @State private var scheduleDraftTime: String = "09:00"
    @State private var scheduleDraftPrompt: String = ""
    @State private var scheduleDraftAgentID: String = "auto"
    @State private var scheduleDraftError: String? = nil
    @State private var isFileIntakeSheetPresented: Bool = false
    @State private var isQuickActionMenuPresented = false
    @State private var collaborationStatusTick: Int = 0
    @State private var collaborationStatusRefreshTask: Task<Void, Never>? = nil
    @State private var latestEventType: AgentEventType? = nil
    @State private var latestEventTimestamp: Date? = nil
    @State private var latestToolName: String? = nil
    @State private var currentWorkflowStatus: WorkflowStatus? = nil

    private let panelChromePadding: CGFloat = 20
    
    private var bgColor: Color {
        manager.isDarkMode ? Color.black.opacity(isCollapsed ? 0.4 : 0.8) : Color.white.opacity(isCollapsed ? 0.3 : 0.75)
    }
    private var textColor: Color {
        manager.isDarkMode ? .white : .black
    }

    private var panelWidth: CGFloat {
        if isCollapsed { return 300 }
        if manager.firstLaunchState.shouldShowOnboarding { return 360 }
        return selectedTab == 0 ? 300 : 600
    }

    private var panelHeight: CGFloat {
        if isCollapsed { return 40 }
        if manager.firstLaunchState.shouldShowOnboarding { return 620 }
        return 500
    }

    private var windowWidth: CGFloat {
        panelWidth + panelChromePadding
    }

    private var windowHeight: CGFloat {
        panelHeight + panelChromePadding
    }

    private var collaborationStatus: TeamCollaborationStatus {
        TeamCollaborationStatusProvider.currentStatus(
            isWorkflowRunning: manager.isWorkflowRunning,
            workflowStatus: currentWorkflowStatus,
            teamRuntimeState: manager.teamRuntimeState,
            latestEventType: latestEventType,
            latestToolName: latestToolName,
            latestEventTimestamp: latestEventTimestamp,
            idleIndex: collaborationStatusTick,
            currentTask: manager.currentMainTask,
            activeAgentNames: manager.activeAgents.map(\.displayName)
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── 헤더 (더블 클릭으로 접기/펼치기) ──
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(selectedTab == 0 ? Color.orange : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(selectedTab == 0 ? "팀 협업 중" : "팀 워크룸")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
                .overlay(WindowDragHandle())
                
                HStack(spacing: 14) {
                    if !isCollapsed {
                        // 탭 전환 버튼
                        Button(action: { selectedTab = (selectedTab == 0 ? 1 : 0) }) {
                            Image(systemName: selectedTab == 0 ? "bubble.left.and.bubble.right.fill" : "person.3.fill")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(selectedTab == 0 ? "팀 워크룸 보기" : "협업 상태 보기")
                        .accessibilityLabel(selectedTab == 0 ? "팀 워크룸 보기" : "협업 상태 보기")
                    }

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: isCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isCollapsed ? "펼치기" : "접기")
                    .accessibilityLabel(isCollapsed ? "펼치기" : "접기")

                    Button(action: { manager.hideStatusWindow() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("협업창 닫기")
                    .accessibilityLabel("협업창 닫기")
                }
                .foregroundColor(manager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            if !isCollapsed {
                // ── 첫 실행 온보딩 (WP1: 통합 카드, 팀 패널에서는 간결하게만) ──
                if manager.firstLaunchState.shouldShowOnboarding {
                    FirstLaunchOnboardingFlowView(
                        manager: manager,
                        onOpenSettings: { manager.showSettingsWindow() }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider().background(textColor.opacity(0.05))

                if selectedTab == 0 {
                    // ── 탭 0: 에이전트 리스트 ──
                    agentListView
                } else {
                    // ── 탭 1: 팀 워크룸 (로그) ──
                    chatroomView
                }
            }
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
        .onChange(of: selectedTab) { _, _ in
            if !isCollapsed {
                manager.updateStatusWindowSize(width: windowWidth, height: windowHeight)
            }
        }
        .onChange(of: isCollapsed) { _, _ in
            manager.updateStatusWindowSize(width: windowWidth, height: windowHeight)
        }
        .onChange(of: manager.firstLaunchState.shouldShowOnboarding) { _, _ in
            if !isCollapsed {
                manager.updateStatusWindowSize(width: windowWidth, height: windowHeight)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: isCollapsed ? 20 : 24)
                    .fill(bgColor)
                    .background(
                        RoundedRectangle(cornerRadius: isCollapsed ? 20 : 24)
                            .fill(manager.isDarkMode ? Color.white.opacity(0.05) : Color.blue.opacity(0.03))
                    )
                RoundedRectangle(cornerRadius: isCollapsed ? 20 : 24)
                    .stroke(textColor.opacity(0.2), lineWidth: 1)
            }
        )
        // schedulePopupCard 오버레이 제거됨 (WP5: 사이드바 단일 진입점)
        .sheet(isPresented: $isFileIntakeSheetPresented) {
            FileIntakeView(
                onResult: { result in
                    handleFileIntakeResult(result)
                },
                onPromptAction: { prompt in
                    handleFileIntakePrompt(prompt)
                }
            )
        }
        .shadow(color: Color.black.opacity(manager.isDarkMode ? 0.3 : 0.08), radius: 15, x: 0, y: 8)
        .padding(10)
        .onAppear {
            manager.updateStatusWindowSize(width: windowWidth, height: windowHeight)
            startCollaborationStatusRefreshLoop()
        }
        .onChange(of: manager.isWorkflowRunning) { _, _ in
            Task { await refreshCollaborationStatus() }
        }
        .onChange(of: manager.currentWorkflowID?.uuidString ?? "") { _, _ in
            Task { await refreshCollaborationStatus() }
        }
        .onDisappear {
            collaborationStatusRefreshTask?.cancel()
            collaborationStatusRefreshTask = nil
        }
        // Round 278 2-A: 승인 후 재실행 — ApprovalRequiredCardView가 발행한 알림 수신
        .onReceive(NotificationCenter.default.publisher(for: .approvalApprovedRerunRequested)) { notification in
            guard let userInfo = notification.userInfo,
                  let notifRoomID = userInfo["roomID"] as? UUID,
                  let originalMessage = userInfo["originalUserMessage"] as? String,
                  notifRoomID == manager.selectedTeamWorkroomID else { return }
            // 원본 메시지를 다시 워크룸 프롬프트로 디스패치 → WorkflowOrchestrator 재실행
            dispatchWorkroomPrompt(originalMessage, roomID: notifRoomID)
        }
    }
    
    // MARK: - 하위 뷰 (에이전트 리스트)
    // WP7: 협업 상태 배너 압축 — 2줄 카드 → 1줄 컴팩트 바 (~32px)
    private var collaborationStatusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: collaborationStatus.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(collaborationStatus.accentColor)

            Text(collaborationStatus.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textColor.opacity(0.75))
                .lineLimit(1)

            if let agentName = collaborationStatus.agentName {
                Text("· \(agentName)")
                    .font(.system(size: 10))
                    .foregroundColor(textColor.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            if collaborationStatus.kind == .completed {
                Circle().fill(Color.green).frame(width: 6, height: 6)
            } else if collaborationStatus.kind == .failed {
                Circle().fill(Color.red).frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(collaborationStatus.accentColor.opacity(manager.isDarkMode ? 0.08 : 0.05))
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var agentListView: some View {
        VStack(spacing: 0) {
            collaborationStatusBanner

            Divider().background(textColor.opacity(0.05))

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(manager.activeAgents) { agent in
                        StatusAgentRow(agent: agent, isDarkMode: manager.isDarkMode)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { @MainActor in
                                    manager.openPersonalChat(for: agent.id)
                                }
                            }
                            .onTapGesture(count: 2) {
                                Task { @MainActor in
                                    manager.openPersonalChat(for: agent.id)
                                    manager.showChat(for: agent)
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(WindowDragBlocker())

            Divider().background(textColor.opacity(0.05))

            // ── 하단 컨트롤 바 ──
            HStack {
                // 좌측: 소리 + 음성모드
                HStack(spacing: 6) {
                    headerIconButton(
                        systemName: manager.isSilentMode ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        tint: TTSProductPolicy.userFacingTTSEnabled
                            ? (manager.isSilentMode ? .red.opacity(0.75) : textColor.opacity(0.42))
                            : textColor.opacity(0.22),
                        label: TTSProductPolicy.userFacingTTSEnabled
                            ? (manager.isSilentMode ? "소리 켜기" : "무음 모드")
                            : "음성 출력 준비 중",
                        action: { manager.isSilentMode.toggle() },
                        disabled: !TTSProductPolicy.userFacingTTSEnabled
                    )
                    headerIconButton(
                        systemName: "waveform",
                        tint: manager.isVoiceMode ? .blue.opacity(0.85) : textColor.opacity(0.30),
                        label: manager.isVoiceMode ? "음성 모드 끄기" : "음성 모드 켜기",
                        action: { manager.isVoiceMode.toggle() }
                    )
                }

                Spacer()

                // 우측: 다크모드 + 설정
                HStack(spacing: 6) {
                    headerIconButton(
                        systemName: manager.isDarkMode ? "moon.stars.fill" : "sun.max.fill",
                        tint: manager.isDarkMode ? .yellow.opacity(0.86) : .orange.opacity(0.78),
                        label: manager.isDarkMode ? "라이트 모드로 전환" : "다크 모드로 전환",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                manager.isDarkMode.toggle()
                            }
                        }
                    )
                    headerIconButton(
                        systemName: "gearshape.fill",
                        tint: textColor.opacity(0.36),
                        label: "설정 열기",
                        action: { manager.showSettingsWindow() }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 하위 뷰 (팀 채팅방 — iMessage 스타일)
    private var chatroomView: some View {
        HStack(spacing: 0) {
            // ── 좌측: 방 목록 사이드바 ──
            chatroomSidebar
            
            Divider().background(textColor.opacity(0.08))
            
            // ── 우측: 선택된 방의 채팅 로그 ──
            chatroomLogView
        }
    }

    private var chatroomSidebar: some View {
        VStack(spacing: 0) {
            chatroomSidebarHeader
            
            Divider().background(textColor.opacity(0.05))

            ScrollView {
                VStack(spacing: 4) {
                    let filteredRooms = manager.rooms.filter { $0.agentIDs.contains("team_all") || $0.agentIDs.count > 1 }
                    ForEach(filteredRooms) { room in
                        RoomRowView(
                            room: room,
                            isSelected: manager.selectedTeamWorkroomID == room.id,
                            isDarkMode: manager.isDarkMode,
                            isDeleteMode: isDeleteMode,
                            onRename: {
                                roomToRename = room
                                newName = room.name
                                showRenameAlert = true
                            },
                            onApplyBlogTemplate: {
                                manager.applyRoomTemplate(.blogWriting, to: room.id)
                            },
                            onApplyGeneralTemplate: {
                                manager.applyRoomTemplate(.general, to: room.id)
                            },
                            onDelete: {
                                roomToDelete = room
                            }
                        )
                        .onTapGesture {
                            if isDeleteMode {
                                roomToDelete = room
                            } else {
                                // Round 241A: selectTeamWorkroom — selectedTeamWorkroomID 독립 유지
                                let previousRoomID = manager.selectedTeamWorkroomID
                                manager.selectTeamWorkroom(room.id)
                                // Character reaction: room switched → .idle
                                if let prev = previousRoomID, prev != room.id {
                                    CharacterReactionEventSink.shared.notifyRoomSwitched(
                                        fromRoomID: prev, toRoomID: room.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
            }
            .background(WindowDragBlocker())
            .alert("이름 변경", isPresented: $showRenameAlert) {
                TextField("새 이름", text: $newName)
                Button("변경") {
                    if let r = roomToRename {
                        manager.renameRoom(id: r.id, newName: newName)
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("새 이름을 입력하세요.")
            }
            .alert(item: $roomToDelete) { room in
                Alert(
                    title: Text("\"\(room.name)\" 삭제"),
                    message: Text("이 채팅방의 모든 대화 내역이 삭제됩니다. 계속하시겠습니까?"),
                    primaryButton: .destructive(Text("삭제")) {
                        manager.deleteRoom(id: room.id)
                        if manager.rooms.isEmpty { isDeleteMode = false }
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }

            Divider().background(textColor.opacity(0.06))
            scheduleSidebarButton
        }
        .frame(width: 140)
        .background(manager.isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
    }

    private var chatroomSidebarHeader: some View {
        HStack {
            Text("워크룸")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(textColor.opacity(0.5))
            Spacer()
            // 삭제 모드 토글 (−)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { isDeleteMode.toggle() }
            }) {
                if isDeleteMode {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                } else {
                    ZStack {
                        if manager.isDarkMode {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                            Image(systemName: "minus")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.black)
                        } else {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            // 채팅방 추가 (+)
            Button(action: {
                isDeleteMode = false
                manager.createRoom(name: "워크룸 \(manager.rooms.count + 1)")
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("워크룸 추가")
            Button(action: {
                isDeleteMode = false
                manager.createBlogWritingRoom()
            }) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.green)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("콘텐츠 초안 보조 워크룸 추가")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 빠른 기능 메뉴 (두루마리 아이콘 팝오버)
    private var quickActionMenuView: some View {
        QuickActionMenuContent(
            isDark: manager.isDarkMode,
            onPrompt: { prompt in
                isQuickActionMenuPresented = false
                inputText = prompt
            },
            onFileIntake: {
                isQuickActionMenuPresented = false
                isFileIntakeSheetPresented = true
            }
        )
    }

    @ViewBuilder
    private func quickMenuSection(
        label: String,
        isDark: Bool,
        items: [(icon: String, title: String, desc: String, prompt: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(action: {
                    isQuickActionMenuPresented = false
                    guard let roomID = manager.selectedTeamWorkroomID else { return }
                    dispatchWorkroomPrompt(item.prompt, roomID: roomID)
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue.opacity(0.85))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isDark ? .white : .primary)
                            Text(item.desc)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0))
                )
            }
        }
    }

    private var scheduleSidebarButton: some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                manager.isSchedulePanelPresented.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(manager.isSchedulePanelPresented ? .orange : textColor.opacity(0.5))
                    if !manager.automationTasks.isEmpty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                            .offset(x: 3, y: -2)
                    }
                }
                Text("예약 작업")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textColor.opacity(manager.isSchedulePanelPresented ? 0.78 : 0.48))
                if !manager.automationTasks.isEmpty {
                    Text("\(manager.automationTasks.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(manager.isSchedulePanelPresented ? Color.orange.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .help("예약 작업")
    }

    private var chatroomLogView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {

                        // ── WorkroomHomeView: 대화가 없을 때만 표시 (isBeginnerMode와 무관) ──
                        if manager.teamChatLogs.isEmpty {
                            // Round 241A: selectedTeamWorkroomID 기준 — 개인 대화 전환 시 오염 방지
                            let roomArtifactsForHome: [IndexedArtifact] = {
                                if let rid = manager.selectedTeamWorkroomID { return manager.recentArtifacts(for: rid) }
                                return []
                            }()
                            let homeModel = WorkroomHomeModel.fromRuntime(
                                roomID: manager.selectedTeamWorkroomID ?? UUID(),
                                roomTitle: manager.rooms.first(where: { $0.id == manager.selectedTeamWorkroomID })?.name ?? "워크룸",
                                recentArtifacts: roomArtifactsForHome
                            )
                            WorkroomHomeView(
                                model: homeModel,
                                manager: manager,
                                isDarkMode: manager.isDarkMode,
                                onPrimaryActionTapped: { action in
                                    handleWorkroomAction(action)
                                },
                                onNextActionTapped: { action in
                                    handleWorkroomNextAction(action)
                                },
                                onPromptDispatched: { prompt in
                                    guard let roomID = manager.selectedTeamWorkroomID else { return }
                                    dispatchWorkroomPrompt(prompt, roomID: roomID)
                                },
                                onPromptPrefilled: { prompt in
                                    inputText = prompt
                                }
                            )
                            .padding(.bottom, manager.teamChatLogs.isEmpty ? 0 : 8)
                        }

                        if let teamRoomID = manager.selectedTeamWorkroomID,
                           let latestChainRun = chainRunStore.latestRun(for: teamRoomID) {
                            ChainRunStatusView(
                                chainRun: latestChainRun,
                                isDarkMode: manager.isDarkMode
                            )
                            .padding(.bottom, 4)
                        }

                        if manager.teamChatLogs.isEmpty && !manager.isBeginnerMode {
                            // standard 빈 상태 (이미 WorkroomHomeView가 위에 표시됨)
                        }

                        ForEach(Array(manager.teamChatLogs.enumerated()), id: \.element.id) { index, log in
                            if index == 0 || !Calendar.current.isDate(
                                log.timestamp, inSameDayAs: manager.teamChatLogs[index - 1].timestamp
                            ) {
                                HStack {
                                    Spacer()
                                    Text(log.timestamp, style: .date)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(textColor.opacity(0.4))
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Capsule().fill(textColor.opacity(0.06)))
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }

                            HStack(alignment: .top, spacing: 6) {
                                if log.isUser { Spacer() }
                                VStack(alignment: log.isUser ? .trailing : .leading, spacing: 2) {
                                    Text(log.isUser ? "나" : log.agentName)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(log.isUser ? .blue : (manager.allAvailableAgents.first(where: { $0.id == log.agentID })?.color ?? .orange))
                                    CopyableMessageContainer(text: log.text, isUser: log.isUser) {
                                        if log.skillID != nil {
                                            SkillResultRendererView(
                                                skillID: log.skillID,
                                                text: log.text,
                                                isDarkMode: manager.isDarkMode,
                                                isUser: log.isUser
                                            )
                                        } else if log.isUser {
                                            Text(log.text)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10).padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.blue)
                                                )
                                        } else {
                                            Group {
                                                if log.presentationStyle == .casualTypewriter,
                                                   ChatTypingPolicy.shouldAnimate(
                                                    text: log.text,
                                                    isUser: log.isUser,
                                                    isSkillResult: log.skillID != nil
                                                ) {
                                                    TypewriterTextView(text: log.text)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(textColor)
                                                } else {
                                                    MarkdownTextView(
                                                        text: log.text,
                                                        isDarkMode: manager.isDarkMode
                                                    )
                                                }
                                            }
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.mtCardBackground)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .strokeBorder(Color.mtCardBorder, lineWidth: 0.5)
                                                    )
                                            )
                                        }
                                    }
                                    if !log.sources.isEmpty {
                                        SourceChipsView(sources: log.sources, isDarkMode: manager.isDarkMode)
                                            .frame(maxWidth: 220, alignment: .leading)
                                    }
                                    Text(log.timestamp, style: .time)
                                        .font(.system(size: 8))
                                        .foregroundColor(textColor.opacity(0.35))
                                }
                                if !log.isUser { Spacer() }
                            }
                            .id(log.id)
                        }
                        // ── Artifact 카드 (ScrollView 내부 — 스크롤 가능) ──
                        // Round 241A: selectedTeamWorkroomID 기준
                        let roomArtifacts: [IndexedArtifact] = {
                            if let rid = manager.selectedTeamWorkroomID { return manager.recentArtifacts(for: rid) }
                            return []
                        }()
                        if !roomArtifacts.isEmpty {
                            Divider().background(textColor.opacity(0.06))
                                .padding(.vertical, 4)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(roomArtifacts, id: \.id) { artifact in
                                        ArtifactCardView(artifact: artifact)
                                            .frame(width: 240)
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                            }
                            .frame(maxHeight: 110)
                        }
                    }
                    .padding(12)
                }
                .background(WindowDragBlocker())
                .frame(maxHeight: .infinity)
                .onChange(of: manager.teamChatLogs.count) { _, _ in
                    if let last = manager.teamChatLogs.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Round 247A: Pending observation inbox (selectedTeamWorkroomID 기준)
            // currentRoomID fallback 금지, 개인방 observation 표시 금지
            if let teamRoomID = manager.selectedTeamWorkroomID {
                ObservationInboxView(
                    roomID: teamRoomID,
                    observationService: manager.observationService,
                    onAnalyze: { obs in manager.analyzeObservation(obs, in: teamRoomID) },
                    onIgnore: { obs in manager.ignoreObservation(obs) }
                )
            }

            // ── 하단: 입력창 (팀 채팅 + 첨부파일) ──
            // layoutPriority(1): ScrollView보다 우선 공간 확보 → 잘림 방지
            VStack(spacing: 0) {
                let activeRoomID = manager.selectedTeamWorkroomID
                let isTeamActive = activeRoomID.map { manager.isWorkflowRunning(for: $0) } == true
                    || (manager.teamRuntimeState?.roomID == activeRoomID && manager.teamRuntimeState?.isActive == true)
                // Round 278 1-F: 작업 중 인디케이터 — Claude/Gemini 수준 "동작 중" 표시
                // 1) 상단 1px 슬라이딩 진행 바
                if isTeamActive {
                    WorkflowProgressBarView(accentColor: .blue)
                }

                Divider().background(textColor.opacity(0.08))

                // Round 278 1-F: 2) 상태 텍스트 + 점 애니메이션 인디케이터
                if isTeamActive,
                   let statusText = TeamRuntimeStatusCopy.displayText(
                       workflowStatusText: activeRoomID.flatMap { manager.workflowStatusText(for: $0) },
                       teamState: manager.teamRuntimeState?.roomID == activeRoomID ? manager.teamRuntimeState : nil
                   ) {
                    WorkflowProgressIndicatorView(
                        statusText: statusText,
                        accentColor: .blue
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // 첨부파일 미리보기
                if !pendingAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pendingAttachments) { attachment in
                                AttachmentChip(attachment: attachment) {
                                    pendingAttachments.removeAll { $0.id == attachment.id }
                                }
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                    }
                }

                if let attachmentError {
                    Text(attachmentError)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue.opacity(0.78))
                        Text("팀 워크룸 입력")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(textColor.opacity(0.58))
                        if let roomName = manager.rooms.first(where: { $0.id == activeRoomID })?.name {
                            Text(roomName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(textColor.opacity(0.38))
                                .lineLimit(1)
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Button(action: openTeamFilePicker) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 28)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // ── 빠른 기능 메뉴 (두루마리 아이콘) ──
                        Button(action: { isQuickActionMenuPresented.toggle() }) {
                            Image(systemName: "scroll")
                                .font(.system(size: 14))
                                .foregroundColor(isQuickActionMenuPresented ? .blue : .secondary.opacity(0.7))
                                .frame(width: 24, height: 28)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("할 수 있는 것 보기")
                        .popover(isPresented: $isQuickActionMenuPresented, arrowEdge: .bottom) {
                            quickActionMenuView
                        }

                        TextField("팀원들에게 업무나 메시지를 입력하세요", text: $inputText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.mtTextPrimary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isTargetedForDrop ? Color.blue.opacity(0.1) : Color.mtInputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isTargetedForDrop ? Color.blue : Color.mtCardBorder, lineWidth: 1)
                                    )
                            )
                            .onSubmit { sendTeamMessage() }

                        // ── 중지 버튼 (workflow 실행 중일 때만 표시) ──
                        if manager.isWorkflowRunning {
                            Button(action: {
                                // Round 241A: selectedTeamWorkroomID 기준
                                guard let roomID = manager.selectedTeamWorkroomID else { return }
                                WorkflowOrchestrator.shared.cancelCurrentWorkflow(roomID: roomID, manager: manager)
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.red.opacity(0.8))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("작업 중지")
                        } else {
                            Button(action: sendTeamMessage) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor((inputText.isEmpty && pendingAttachments.isEmpty) ? .gray.opacity(0.4) : .blue)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(inputText.isEmpty && pendingAttachments.isEmpty)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.mtCardBackground.opacity(manager.isDarkMode ? 0.96 : 0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.mtCardBorder, lineWidth: 0.6)
                        )
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url = url else { return }
                        Task { @MainActor in
                            if let a = await loadTeamAttachment(from: url) {
                                pendingAttachments.append(a)
                                attachmentError = nil
                            } else {
                                attachmentError = "첨부를 읽지 못했어요. 파일 권한이나 형식을 확인해 주세요."
                            }
                        }
                    }
                }
                return true
            }
            }
            .layoutPriority(1)
        }
    }

    private var scheduleTasksPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
                Text("예약 작업")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textColor.opacity(0.55))
                Spacer()
                if !manager.automationTasks.isEmpty {
                    Text("\(manager.automationTasks.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                }
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                        manager.isSchedulePanelPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(textColor.opacity(0.38))
                }
                .buttonStyle(.plain)
            }

            scheduleComposer

            if manager.automationTasks.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 10))
                    Text("등록된 예약 작업가 없습니다.")
                        .font(.system(size: 10))
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundColor(textColor.opacity(0.32))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(manager.automationTasks.sorted { $0.nextRunAt < $1.nextRunAt }.enumerated()), id: \.element.id) { index, task in
                            scheduleTaskChip(index: index + 1, task: task)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(manager.isDarkMode ? Color.white.opacity(0.06) : Color.white.opacity(0.92))
                .shadow(color: .black.opacity(manager.isDarkMode ? 0.18 : 0.08), radius: 12, x: 0, y: 5)
        )
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    // schedulePopupCard 제거됨 (WP5: 사이드바 scheduleSidebarButton 단일 진입점)

    private var scheduleComposer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TextField("09:00", text: $scheduleDraftTime)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 42)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(textColor.opacity(0.06)))

                Picker("", selection: $scheduleDraftAgentID) {
                    Text("자동").tag("auto")
                    ForEach(manager.allAvailableAgents) { agent in
                        Text(scheduleAgentMenuLabel(for: agent)).tag(agent.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 76)

                TextField("업무 내용", text: $scheduleDraftPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(textColor.opacity(0.06)))

                Button(action: addScheduleFromPanel) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(canAddSchedule ? .orange : textColor.opacity(0.25))
                }
                .buttonStyle(.plain)
                .disabled(!canAddSchedule)
                .help("스케줄 추가")
            }

            if let scheduleDraftError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(scheduleDraftError)
                        .font(.system(size: 11))
                }
                .foregroundColor(.red.opacity(0.85))
            }
        }
    }

    private func scheduleTaskChip(index: Int, task: AgentWindowManager.AutomationTask) -> some View {
        HStack(spacing: 6) {
            Text("\(index)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.orange))
            VStack(alignment: .leading, spacing: 1) {
                Text(scheduleChipTitle(for: task))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                Text(task.prompt)
                    .font(.system(size: 9))
                    .foregroundColor(textColor.opacity(0.65))
                    .lineLimit(1)
            }
            Button(action: { manager.cancelAutomationTask(id: task.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(textColor.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(manager.isDarkMode ? Color.white.opacity(0.06) : Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var canAddSchedule: Bool {
        !scheduleDraftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parseScheduleDraftDate() != nil
    }

    private func scheduleChipTitle(for task: AgentWindowManager.AutomationTask) -> String {
        guard let assignedID = task.assignedAgentID,
              let agent = manager.allAvailableAgents.first(where: { $0.id == assignedID }) else {
            return task.scheduleText
        }
        let status = manager.activeAgents.contains(where: { $0.id == assignedID }) ? "" : " 없음"
        return "\(task.scheduleText) · \(agent.displayName)\(status)"
    }

    private func scheduleAgentMenuLabel(for agent: AgentWindowManager.AgentConfig) -> String {
        manager.activeAgents.contains(where: { $0.id == agent.id })
            ? agent.displayName
            : "\(agent.displayName) 없음"
    }

    private func addScheduleFromPanel() {
        let prompt = scheduleDraftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            scheduleDraftError = "업무 내용을 입력해 주세요."
            return
        }
        guard let nextRunAt = parseScheduleDraftDate() else {
            scheduleDraftError = "시간은 09:00 형식으로 입력해 주세요."
            return
        }
        guard let roomID = manager.selectedTeamWorkroomID else {
            scheduleDraftError = "스케줄을 등록할 워크룸을 먼저 선택해 주세요."
            return
        }

        let assignedID = scheduleDraftAgentID == "auto" ? nil : scheduleDraftAgentID
        manager.addAutomationTask(
            prompt: prompt,
            nextRunAt: nextRunAt,
            roomID: roomID,
            assignedAgentID: assignedID
        )
        scheduleDraftPrompt = ""
        scheduleDraftError = nil
    }

    private func parseScheduleDraftDate() -> Date? {
        let parts = scheduleDraftTime
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let today = Calendar.current.date(from: components) else { return nil }
        return today > Date() ? today : Calendar.current.date(byAdding: .day, value: 1, to: today)
    }

    private func startCollaborationStatusRefreshLoop() {
        collaborationStatusRefreshTask?.cancel()
        collaborationStatusRefreshTask = Task {
            while !Task.isCancelled {
                await refreshCollaborationStatus()
                let shouldStayHot = await MainActor.run { manager.isWorkflowRunning }
                let interval: UInt64 = shouldStayHot ? 4_000_000_000 : 30_000_000_000
                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    break
                }
            }
        }
    }

    private func refreshCollaborationStatus() async {
        // Round 241A: selectedTeamWorkroomID 기준 — 개인 대화 전환 시 오염 방지
        let roomID = await MainActor.run { manager.selectedTeamWorkroomID }
        let workflowID = await MainActor.run { manager.currentWorkflowID }
        let recentEvents: [AgentEvent]
        if let roomID {
            recentEvents = await AgentEventBus.shared.recentEvents(for: roomID, limit: 50)
        } else {
            recentEvents = await AgentEventBus.shared.allRecentEvents(limit: 50)
        }
        let scopedEvents = recentEvents.filter { event in
            guard let workflowID else { return true }
            return event.workflowID == workflowID
        }
        let latest = scopedEvents.last ?? recentEvents.last
        let workflowStatus = await MainActor.run {
            workflowID.flatMap { WorkflowRunStore.shared.record(for: $0)?.status }
        }

        await MainActor.run {
            self.latestEventType = latest?.type
            self.latestEventTimestamp = latest?.timestamp
            self.latestToolName = latest?.payload.toolName
            self.currentWorkflowStatus = workflowStatus
            if !manager.isWorkflowRunning {
                self.collaborationStatusTick += 1
            }
        }
    }

    private func openTeamFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.allowedAttachmentContentTypes
        panel.begin { response in
            guard response == .OK else { return }
            Task {
                for url in panel.urls {
                    if let a = await loadTeamAttachment(from: url) {
                        await MainActor.run {
                            pendingAttachments.append(a)
                            attachmentError = nil
                        }
                    } else {
                        await MainActor.run {
                            attachmentError = "첨부를 읽지 못했어요. 파일 권한이나 형식을 확인해 주세요."
                        }
                    }
                }
            }
        }
    }

    private func loadTeamAttachment(from url: URL) async -> ChatAttachment? {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let fileName = url.lastPathComponent
        let type = ChatAttachment.AttachmentType.from(fileName: fileName)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let textContent = FileIntakeService.extractAttachmentText(from: url)
            ?? FileContentExtractor.extractText(from: url)
        return ChatAttachment(fileName: fileName, fileSize: fileSize, type: type, textContent: textContent, localPath: url.path)
    }

    private static var allowedAttachmentContentTypes: [UTType] {
        var types: [UTType] = [.text, .plainText, .pdf, .image, .data]
        let extensions = ["md", "markdown", "csv", "xlsx", "docx", "pptx", "hwp", "hwpx"]
        types.append(contentsOf: extensions.compactMap { UTType(filenameExtension: $0) })
        return types
    }

    private func sendTeamMessage() {
        guard !inputText.isEmpty || !pendingAttachments.isEmpty else { return }
        // Round 241A: selectedTeamWorkroomID 기준 캡처 — 개인 대화 전환 시 오염 차단
        guard let roomIDAtSend = manager.selectedTeamWorkroomID else { return }

        let text = inputText
        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []

        // ── 단일 Task 안에서 순서대로 처리 — 중복 dispatch 원천 차단 ──
        Task {
            // a) memory/slash command 처리 — roomIDAtSend 고정
            if await ConversationMemory.handleChatCommand(
                text,
                roomID: roomIDAtSend,
                manager: manager,
                currentAgent: manager.fallbackTeamLeader()
            ) { return }

            // b) slash command 종료
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") else { return }

            // c) 사용자 채팅 로그 — roomIDAtSend 명시 (Task 내부에서 currentRoomID 읽기 금지)
            let attachmentContext = ConversationMemory.buildAttachmentContext(from: attachments)
            let fullText = attachmentContext.isEmpty ? text : text + attachmentContext

            _ = await MainActor.run {
                manager.addChatLog(
                    roomID: roomIDAtSend,
                    agentID: "user", agentName: "나",
                    text: text.isEmpty ? "[첨부파일 \(attachments.count)개]" : text,
                    isUser: true
                )
            }

            // d) WorkflowOrchestrator dispatch — roomIDAtSend 고정
            await WorkflowOrchestrator.shared.dispatch(
                userMessage: fullText,
                roomID: roomIDAtSend,
                manager: manager
            )
        }
    }

    // MARK: - 방 행 (사이드바)
    private struct RoomRowView: View {
        let room: AgentWindowManager.ChatRoom
        let isSelected: Bool
        let isDarkMode: Bool
        var isDeleteMode: Bool = false
        var onRename: () -> Void
        var onApplyBlogTemplate: () -> Void
        var onApplyGeneralTemplate: () -> Void
        var onDelete: () -> Void

        var body: some View {
            HStack(spacing: 6) {
                // 삭제 모드: 빨간 원 아이콘 / 일반: RoomKind별 아이콘
                if isDeleteMode {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: room.effectiveProfile.mode == .blogWriting ? "doc.text.magnifyingglass" : (room.computedRoomKind == .teamWorkroom ? "person.3.fill" : "person.fill"))
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
                }
                
                // 12글자까지 허용하고 왼쪽 정렬
                Text(room.name.prefix(12))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? .blue : (isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                
                if isSelected && !isDeleteMode {
                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.blue.opacity(0.1) : Color.clear))
            .animation(.easeInOut(duration: 0.15), value: isDeleteMode)
            .contextMenu {
                Button(action: onRename) {
                    Label("이름 변경", systemImage: "pencil")
                }
                Button(action: onApplyBlogTemplate) {
                    Label("콘텐츠 초안 보조", systemImage: "doc.text.magnifyingglass")
                }
                if room.effectiveProfile.mode != .general {
                    Button(action: onApplyGeneralTemplate) {
                        Label("일반 워크룸으로 전환", systemImage: "person.3.fill")
                    }
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("워크룸 삭제", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - 하위 뷰 (헤더 통합형 컨트롤)
    private var headerControlStrip: some View {
        HStack(spacing: 6) {
            headerIconButton(
                systemName: manager.isSilentMode ? "speaker.slash.fill" : "speaker.wave.2.fill",
                tint: TTSProductPolicy.userFacingTTSEnabled
                    ? (manager.isSilentMode ? .red.opacity(0.75) : textColor.opacity(0.42))
                    : textColor.opacity(0.22),
                label: TTSProductPolicy.userFacingTTSEnabled
                    ? (manager.isSilentMode ? "소리 켜기" : "무음 모드")
                    : "음성 출력 준비 중",
                action: { manager.isSilentMode.toggle() },
                disabled: !TTSProductPolicy.userFacingTTSEnabled
            )

            headerIconButton(
                systemName: "waveform",
                tint: manager.isVoiceMode ? .blue.opacity(0.85) : textColor.opacity(0.30),
                label: manager.isVoiceMode ? "음성 모드 끄기" : "음성 모드 켜기",
                action: { manager.isVoiceMode.toggle() }
            )

            headerIconButton(
                systemName: manager.isDarkMode ? "moon.stars.fill" : "sun.max.fill",
                tint: manager.isDarkMode ? .yellow.opacity(0.86) : .orange.opacity(0.78),
                label: manager.isDarkMode ? "라이트 모드로 전환" : "다크 모드로 전환",
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.isDarkMode.toggle()
                    }
                }
            )

            headerIconButton(
                systemName: "gearshape.fill",
                tint: textColor.opacity(0.36),
                label: "설정 열기",
                action: { manager.showSettingsWindow() }
            )

            Rectangle()
                .fill(textColor.opacity(0.12))
                .frame(width: 1, height: 14)
                .padding(.leading, 3)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(manager.isDarkMode ? Color.white.opacity(0.045) : Color.black.opacity(0.045))
                .overlay(Capsule().stroke(textColor.opacity(0.08), lineWidth: 1))
        )
    }

    private func headerIconButton(
        systemName: String,
        tint: Color,
        label: String,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }

    private func handleFileIntakeResult(_ result: FileIntakeResult) {
        // Round 241A: selectedTeamWorkroomID 기준
        guard let roomID = manager.selectedTeamWorkroomID ?? manager.rooms.first?.id else { return }

        manager.recordFileIntakeResult(result, roomID: roomID)

        let message: String
        switch result.status {
        case .ready:
            message = """
            파일을 읽었습니다.
            파일: \(result.request.originalFilename)
            먼저 요약/해야 할 일/주의할 점 카드로 남기고 있습니다.
            """
            Task { @MainActor in
                if let artifact = await FileIntakeService.writeFirstResultCard(
                    from: result,
                    roomID: roomID,
                    manager: manager
                ) {
                    manager.addChatLog(
                        roomID: roomID,
                        agentID: "system",
                        agentName: "파일",
                        text: """
                        요약 카드를 만들었습니다.
                        파일: \(artifact.filename)
                        이어서 “답장 초안 만들어줘”, “체크리스트로 바꿔줘”, “보고서로 만들어줘”처럼 요청할 수 있습니다.
                        """,
                        isUser: false,
                        isSystem: true
                    )
                }
            }
        case .planned:
            message = """
            이 파일 형식은 아직 준비 중입니다.
            현재는 TXT, MD, CSV, PDF, XLSX, DOCX, PPTX, HWP, HWPX의 텍스트 추출 중심 처리를 지원합니다.
            """
        case .blocked:
            message = result.userMessage
        case .tooLarge:
            message = result.userMessage
        case .readFailed:
            message = result.userMessage
        case .empty:
            message = result.userMessage
        case .unsupported:
            message = result.userMessage
        }

        manager.addChatLog(
            roomID: roomID,
            agentID: "system",
            agentName: "파일",
            text: message,
            isUser: false,
            isSystem: true
        )
    }

    @MainActor
    private func handleFileIntakePrompt(_ prompt: String) {
        // Round 241A: selectedTeamWorkroomID 기준
        guard let roomID = manager.selectedTeamWorkroomID ?? manager.rooms.first?.id else { return }

        manager.addChatLog(
            roomID: roomID,
            agentID: "user",
            agentName: "나",
            text: prompt,
            isUser: true
        )

        Task {
            await WorkflowOrchestrator.shared.dispatch(
                userMessage: prompt,
                roomID: roomID,
                manager: manager
            )
        }
    }

    // MARK: - Workroom Action Handlers

    /// Workroom primary action dispatch
    private func handleWorkroomAction(_ action: WorkroomPrimaryAction) {
        // Round 241A: selectedTeamWorkroomID 기준
        guard let roomID = manager.selectedTeamWorkroomID else { return }

        switch action {
        case .createDocument:
            inputText = action.dispatchPrompt
        case .handoffFile:
            isFileIntakeSheetPresented = true
        case .organizeToday:
            CharacterReactionEventSink.shared.notifyDocumentGenerationStarted(
                workflowType: "universalDocument", roomID: roomID)
            dispatchWorkroomPrompt(action.dispatchPrompt, roomID: roomID)
        }
    }

    /// Workroom next action dispatch (reuse recent artifacts)
    private func handleWorkroomNextAction(_ action: WorkroomNextAction) {
        // Round 241A: selectedTeamWorkroomID 기준
        guard manager.selectedTeamWorkroomID != nil else { return }
        inputText = action.dispatchPrompt
    }

    /// Helper: dispatch Workroom prompt through WorkflowOrchestrator
    private func dispatchWorkroomPrompt(_ prompt: String, roomID: UUID) {
        manager.addChatLog(
            roomID: roomID,
            agentID: "user",
            agentName: "나",
            text: prompt,
            isUser: true
        )

        Task {
            await WorkflowOrchestrator.shared.dispatch(
                userMessage: prompt,
                roomID: roomID,
                manager: manager
            )
        }
    }

    // handleFirstResultAction 제거 — WP6: AgentChatView에서만 처리
}

// MARK: - QuickActionMenuContent
struct QuickActionMenuContent: View {
    let isDark: Bool
    let onPrompt: (String) -> Void
    let onFileIntake: () -> Void

    private var bg: Color { isDark ? Color(white: 0.12) : Color(white: 0.97) }
    private var dividerColor: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "scroll")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("할 수 있는 것")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isDark ? .white : .primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().background(dividerColor).padding(.horizontal, 8)

                quickMenuSection(
                    label: "문서 만들기",
                    items: [
                        ("doc.text", "회의록", "회의 내용 정리", "아래 회의 메모를 회의록으로 정리해줘.\n\n"),
                        ("checkmark.square", "체크리스트", "할 일을 목록으로 정리", "아래 내용으로 체크리스트를 만들어줘.\n\n"),
                        ("doc.badge.plus", "보고서 초안", "보고서 형태로 정리", "아래 주제와 자료로 보고서 초안을 만들어줘.\n\n")
                    ]
                )

                Divider().background(dividerColor).padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text("파일 & 정보")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    quickMenuButton(
                        icon: "folder",
                        title: "파일 읽기",
                        desc: "첨부 파일을 분석·요약",
                        action: onFileIntake
                    )

                    quickMenuButton(
                        icon: "calendar.badge.checkmark",
                        title: "오늘 할 일",
                        desc: "지금 이어서 할 일 정리",
                        action: { onPrompt("오늘 할 일 정리해줘") }
                    )
                }

                Divider().background(dividerColor).padding(.horizontal, 8)

                quickMenuSection(
                    label: "변환",
                    items: [
                        ("text.alignleft", "요약하기", "핵심만 짧게 정리", "요약할 내용이나 파일을 지정해서 요약해줘.\n\n"),
                        ("tablecells", "표로 바꾸기", "내용을 표 형태로 재정리", "표로 바꿀 내용이나 파일을 지정해서 정리해줘.\n\n"),
                        ("checklist", "체크리스트 변환", "내용을 체크리스트로 변환", "체크리스트로 바꿀 내용이나 파일을 지정해서 정리해줘.\n\n")
                    ]
                )

                Divider().background(dividerColor).padding(.horizontal, 8)

                quickMenuSection(
                    label: "예시로 시작하기",
                    items: [
                        ("play.circle.fill", "샘플 회의록", "샘플 회의 내용으로 시작", BeginnerTaskCard.exampleMeetingPrompt)
                    ]
                )

                Text("메시지 창에 직접 입력해도 됩니다")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 280, height: 440)
        .background(bg)
    }

    @ViewBuilder
    private func quickMenuSection(
        label: String,
        items: [(icon: String, title: String, desc: String, prompt: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                quickMenuButton(
                    icon: item.icon,
                    title: item.title,
                    desc: item.desc,
                    action: { onPrompt(item.prompt) }
                )
            }
        }
    }

    private func quickMenuButton(icon: String, title: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue.opacity(0.85))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDark ? .white : .primary)
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - StatusAgentRow
struct StatusAgentRow: View {
    let agent: AgentWindowManager.AgentConfig
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(agent.color.opacity(isDarkMode ? 0.3 : 0.15))
                    .frame(width: 38, height: 38)
                
                if !agent.fallbackImageName.isEmpty {
                    Image(agent.fallbackImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                } else {
                    Text(agent.emoji).font(.system(size: 20))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName).font(.system(size: 13, weight: .semibold)).foregroundColor(.mtTextPrimary)
                Text(agent.status).font(.system(size: 10)).foregroundColor(.mtTextSecondary)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.mtTextTertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.mtCardBackground)
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.mtCardBorder, lineWidth: 0.5))
        )
    }
}
