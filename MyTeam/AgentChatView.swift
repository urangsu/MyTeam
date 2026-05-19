import SwiftUI
import AppKit
import UniformTypeIdentifiers

// JiggleEffect, IMMessageBubble, DateSeparator, ChatBubble → ChatComponents.swift 로 분리됨

// MARK: - AgentChatView
struct AgentChatView: View {
    let config: AgentWindowManager.AgentConfig
    let onClose: () -> Void

    @EnvironmentObject var manager: AgentWindowManager
    @StateObject private var speechManager = SpeechManager.shared
    @State private var inputText: String = ""
    @State private var preRecordText: String = ""
    @State private var selectedTab: Int = 1

    @State private var activeAgentID: String? = nil
    @State private var agentRoomID: UUID? = nil
    @State private var isSidebarCollapsed: Bool = false

    // 첨부파일
    @State private var pendingAttachments: [ChatAttachment] = []
    @State private var isTargetedForDrop: Bool = false

    // 삭제/편집 모드
    @State private var isEditingProjects: Bool = false
    @State private var isEditingMessages: Bool = false

    // 방 이름 변경
    @State private var renamingRoomID: UUID? = nil
    @State private var renameText: String = ""
    @FocusState private var isRenameFieldFocused: Bool

    // 최소화 (팀 협업창 스타일)
    @State private var isMinimized: Bool = false
    private let minimizedHeight: CGFloat = 52

    var isPersonalChat: Bool = true

    private var agentRooms: [AgentWindowManager.ChatRoom] {
        let targetID = activeAgentID ?? config.id
        // 개인 방만 표시: agentIDs가 정확히 [targetID] 하나인 방만
        return manager.rooms.filter { $0.agentIDs.count == 1 && $0.agentIDs[0] == targetID }
    }

    private var chatHistory: [AgentWindowManager.ChatLog] {
        // 개인창: agentRoomID nil이면 빈 배열 — currentRoomID fallback 금지
        guard let roomID = agentRoomID else { return [] }
        let logs = manager.rooms.first(where: { $0.id == roomID })?.messages ?? []
        let targetID = activeAgentID ?? config.id
        if isPersonalChat {
            // isSystem=true 시스템 내부 로그는 대화창에 절대 노출하지 않음
            return logs.filter { !$0.isSystem && ($0.agentID == targetID || $0.isUser) }
        } else {
            // 팀 워크룸도 시스템 로그 제외
            return logs.filter { !$0.isSystem }
        }
    }

    private var currentAgent: AgentWindowManager.AgentConfig {
        manager.activeAgents.first(where: { $0.id == (activeAgentID ?? config.id) }) ?? config
    }

    // 현재 타이핑 중인 에이전트 (이 채팅방에 해당하는)
    private var typingAgentID: String? {
        let targetID = activeAgentID ?? config.id
        if isPersonalChat {
            return manager.typingAgentIDs.contains(targetID) ? targetID : nil
        }
        return manager.typingAgentIDs.first
    }

    private var bgColor: Color {
        manager.isDarkMode ? Color(red: 0.09, green: 0.09, blue: 0.11) : Color(red: 0.97, green: 0.97, blue: 0.99)
    }
    private var textColor: Color { manager.isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12) }
    private var subTextColor: Color { Color.mtTextSecondary }
    private var dividerColor: Color { manager.isDarkMode ? .white.opacity(0.07) : .black.opacity(0.06) }
    private var inputBgColor: Color { Color.mtInputBackground }

    private var viewWidth: CGFloat {
        if selectedTab == 0 { return 300 }
        return isSidebarCollapsed ? 550 : 600
    }

    var body: some View {
        Group {
            if isMinimized {
                minimizedBarView
                    // 최소화 시: SwiftUI가 NSPanel 크기를 직접 고정
                    .frame(width: 280, height: minimizedHeight)
            } else {
                HStack(spacing: 0) {
                    if selectedTab == 1 {
                        projectSidebarView
                        Divider().background(dividerColor)
                    }

                    VStack(spacing: 0) {
                        headerView
                        Divider().background(dividerColor)

                        if selectedTab == 1 {
                            chatLogView
                        } else {
                            agentStatusView
                        }
                    }
                }
                // 복원 시: NSPanel 크기에 맞게 꽉 채움 (NSPanel이 크기 결정)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // 어디든 탭하면 편집 모드 해제
                .onTapGesture {
                    if isEditingMessages { isEditingMessages = false }
                    if isEditingProjects { isEditingProjects = false }
                    if renamingRoomID != nil {
                        commitRename()
                    }
                }
            }
        }
        .onAppear {
            activeAgentID = config.id
            let targetID = config.id
            if let firstRoom = agentRooms.first {
                agentRoomID = firstRoom.id
            } else {
                manager.createAgentRoom(name: "\(config.name) 대화 1", agentID: targetID)
                // last?.id 대신 agentID로 정확히 찾아 오염 방지
                agentRoomID = manager.rooms.last(where: {
                    $0.agentIDs.count == 1 && $0.agentIDs[0] == targetID
                })?.id
            }
            // 초기 창 크기 강제 설정 (SwiftUI 레이아웃 완료 후 실행)
            DispatchQueue.main.async {
                if manager.savedChatWindowSize() == nil {
                    manager.updateChatWindowSize(id: config.id, width: viewWidth, height: 520,
                                                  minSize: NSSize(width: 300, height: 480))
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if !isMinimized {
                let w = newValue == 0 ? 300 : viewWidth
                DispatchQueue.main.async {
                    manager.updateChatWindowWidth(id: config.id, width: w)
                }
            }
        }
        .onChange(of: isSidebarCollapsed) { _, _ in
            if selectedTab == 1 && !isMinimized {
                let w = viewWidth
                DispatchQueue.main.async {
                    manager.updateChatWindowWidth(id: config.id, width: w)
                }
            }
        }
        .onChange(of: isMinimized) { _, minimized in
            // DispatchQueue.main.async: SwiftUI render cycle 완료 후 AppKit 호출
            // → withAnimation 트랜잭션과 panel.setFrame(animate:) 이중 충돌 방지
            DispatchQueue.main.async {
                if minimized {
                    manager.updateChatWindowSize(id: config.id, width: 280, height: minimizedHeight,
                                                  minSize: NSSize(width: 240, height: minimizedHeight))
                } else {
                    manager.updateChatWindowSize(id: config.id, width: viewWidth, height: 520,
                                                  minSize: NSSize(width: 300, height: 480))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("didSelectAgentForChat"))) { notif in
            if let id = notif.userInfo?["agentID"] as? String {
                withAnimation {
                    activeAgentID = id
                    let filteredRooms = manager.rooms.filter { $0.agentIDs.count == 1 && $0.agentIDs[0] == id }
                    if let firstRoom = filteredRooms.first {
                        agentRoomID = firstRoom.id
                    } else {
                        // 방이 없으면 즉시 생성 (팀 채팅방으로 fallback 방지)
                        let agentName = manager.activeAgents.first(where: { $0.id == id })?.name ?? "대화"
                        manager.createAgentRoom(name: "\(agentName) 대화 1", agentID: id)
                        // rooms.last 대신 agentIDs 기반 정확 탐색 — 오염 방지
                        if let created = manager.rooms.last(where: {
                            $0.agentIDs.count == 1 && $0.agentIDs[0] == id
                        }) {
                            agentRoomID = created.id
                        } else {
                            AppLog.error("[DirectChat] 개인방 생성 후 탐색 실패 agentID=\(id)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 최소화 바 (팀 협업창 스타일)
    private var minimizedBarView: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(currentAgent.color.opacity(manager.isDarkMode ? 0.3 : 0.15))
                    .frame(width: 34, height: 34)
                Image(currentAgent.fallbackImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(currentAgent.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textColor)
                if let last = chatHistory.last {
                    Text(last.text)
                        .font(.system(size: 10))
                        .foregroundColor(subTextColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                // 펼치기 버튼 (팀 현황창의 ↕ 버튼 스타일)
                Button(action: {
                    isMinimized = false  // withAnimation 제거 — AppKit 패널이 자체 animate
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(subTextColor)
                }
                .buttonStyle(PlainButtonStyle())

                // 닫기
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(subTextColor.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bgColor)
    }

    // MARK: - 헤더
    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(currentAgent.color.opacity(manager.isDarkMode ? 0.3 : 0.15))
                    .frame(width: 40, height: 40)
                Image(currentAgent.fallbackImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(currentAgent.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                if selectedTab == 1 {
                    // agentRoomID 기준만 — currentRoomID fallback 금지
                    if let rid = agentRoomID,
                       let room = manager.rooms.first(where: { $0.id == rid }) {
                        Text(room.name)
                            .font(.system(size: 11))
                            .foregroundColor(config.color.opacity(0.8))
                    }
                } else {
                    Text(currentAgent.role)
                        .font(.system(size: 11))
                        .foregroundColor(subTextColor)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = (selectedTab == 0 ? 1 : 0)
                    }
                }) {
                    Image(systemName: selectedTab == 0 ? "bubble.left.and.bubble.right.fill" : "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(subTextColor)
                }

                // 팀 워크룸으로 돌아가기 (개인 대화에서만 표시)
                if isPersonalChat {
                    Button(action: {
                        manager.returnToTeamWorkroom()
                    }) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(subTextColor.opacity(0.7))
                    }
                    .help("팀 워크룸으로")
                }

                if selectedTab == 1 {
                    // 메시지 편집 모드 토글
                    Button(action: {
                        withAnimation { isEditingMessages.toggle() }
                        if isEditingMessages { isEditingProjects = false }
                    }) {
                        Image(systemName: isEditingMessages ? "checkmark.circle.fill" : "trash")
                            .font(.system(size: 14))
                            .foregroundColor(isEditingMessages ? currentAgent.color : subTextColor)
                    }

                    Button(action: {
                        if speechManager.isRecording {
                            speechManager.stopRecording()
                        } else {
                            speechManager.requestAuthorization { authorized in
                                if authorized {
                                    self.preRecordText = self.inputText
                                    speechManager.startRecording()
                                }
                            }
                        }
                    }) {
                        if speechManager.isStarting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                .scaleEffect(0.65)
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic")
                                .foregroundColor(speechManager.isRecording ? .red : subTextColor)
                        }
                    }
                    .disabled(speechManager.isStarting)
                }

                // 최소화 (팀 협업창 스타일)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isMinimized = true
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(subTextColor)
                }

                // 닫기
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(subTextColor.opacity(0.6))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(bgColor)
    }

    // MARK: - 프로젝트 사이드바
    private var projectSidebarView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(currentAgent.fallbackImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                if !isSidebarCollapsed {
                    Text("대화")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(textColor.opacity(0.5))
                }
                Spacer()

                // 사이드바 편집 모드 버튼
                if !isSidebarCollapsed {
                    Button(action: {
                        withAnimation { isEditingProjects.toggle() }
                        if isEditingProjects { isEditingMessages = false }
                        renamingRoomID = nil
                    }) {
                        Image(systemName: isEditingProjects ? "checkmark.circle.fill" : "minus.circle")
                            .font(.system(size: 13))
                            .foregroundColor(isEditingProjects ? currentAgent.color : subTextColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 새 프로젝트 추가 (+ 버튼)
                Button(action: addNewProject) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(currentAgent.color)
                }
                .buttonStyle(PlainButtonStyle())

            }
            .padding(.horizontal, isSidebarCollapsed ? 8 : 12)
            .padding(.vertical, 10)

            Divider().background(dividerColor)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(agentRooms) { room in
                        projectRoomRow(room: room)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }

            Spacer()

            // Quick agent switcher (sidebar 하단)
            if !isSidebarCollapsed {
                AgentQuickSwitchBar(
                    manager: manager,
                    currentAgentID: activeAgentID,
                    onSelectAgent: { agentID in
                        manager.openPersonalChat(for: agentID)
                    }
                )
            }
        }
        .frame(width: isSidebarCollapsed ? 50 : 160)
        .background(manager.isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.08))
    }

    // MARK: - 새 프로젝트 추가
    private func addNewProject() {
        isEditingProjects = false
        isEditingMessages = false
        renamingRoomID = nil
        let targetID = activeAgentID ?? config.id
        let newName = "\(currentAgent.name) 대화 \(agentRooms.count + 1)"
        manager.createAgentRoom(name: newName, agentID: targetID)
        // agentRooms는 computed이므로, rooms.filter 결과에서 마지막 방을 직접 찾음
        DispatchQueue.main.async {
            let newAgentRooms = manager.rooms.filter {
                $0.agentIDs.count == 1 && $0.agentIDs[0] == targetID
            }
            if let newRoom = newAgentRooms.last {
                withAnimation { agentRoomID = newRoom.id }
            }
        }
    }

    // MARK: - 이름 변경 커밋
    private func commitRename() {
        if let rid = renamingRoomID, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
            manager.renameRoom(id: rid, newName: renameText.trimmingCharacters(in: .whitespaces))
        }
        renamingRoomID = nil
        renameText = ""
    }

    @ViewBuilder
    private func projectRoomRow(room: AgentWindowManager.ChatRoom) -> some View {
        let isSelected = agentRoomID == room.id
        let isRenaming = renamingRoomID == room.id

        ZStack(alignment: .topTrailing) {
            // 버튼 대신 HStack 제스처로 대체하여 더블클릭 이벤트 충돌 완전 방지
            HStack(spacing: 6) {
                    Image(systemName: room.effectiveProfile.mode == .blogWriting ? "doc.text.magnifyingglass" : "bubble.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? currentAgent.color : .gray.opacity(0.5))
                    if !isSidebarCollapsed {
                        VStack(alignment: .leading, spacing: 2) {
                            // 이름 변경 인라인 편집
                            if isRenaming {
                                TextField("방 이름", text: $renameText)
                                    .font(.system(size: 11, weight: .bold))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(currentAgent.color)
                                    .focused($isRenameFieldFocused)
                                    .onSubmit { commitRename() }
                                    .onExitCommand { renamingRoomID = nil }
                            } else {
                                Text(room.name)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? currentAgent.color : textColor.opacity(0.7))
                                    .lineLimit(1)
                                    // 텍스트에만 직접 더블탭을 붙여서 Button에 이벤트가 먹히는 것을 우회
                                    .onTapGesture(count: 2) {
                                        guard !isSidebarCollapsed && !isEditingProjects else { return }
                                        renameText = room.name
                                        renamingRoomID = room.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            isRenameFieldFocused = true
                                        }
                                    }
                            }
                            // Round 241A: 개인 대화 사이드바 message preview 금지
                            // 내용 노출 없이 방 이름만 표시
                        }
                        Spacer()
                        if !isRenaming {
                            // Round 241C: unread badge — 상대가 보낸 미읽 메시지만
                            // (내가 보낸 메시지 / system / progress 제외)
                            let unread = manager.unreadCount(for: room.id)
                            if unread > 0 {
                                Text("\(unread)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(isSelected ? currentAgent.color : Color.accentColor.opacity(0.7)))
                            }
                        }
                    }
            }
            .contentShape(Rectangle()) // 빈공간도 클릭하게
            .onTapGesture(count: 2) {
                guard !isSidebarCollapsed && !isEditingProjects else { return }
                renameText = room.name
                renamingRoomID = room.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isRenameFieldFocused = true
                }
            }
            .onTapGesture(count: 1) {
                guard !isEditingProjects else { return }
                withAnimation(.easeInOut(duration: 0.15)) { agentRoomID = room.id }
                // Round 241C: 방을 열 때 읽음 처리
                manager.markRoomRead(room.id)
            }
            .padding(.horizontal, isSidebarCollapsed ? 8 : 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? currentAgent.color.opacity(0.1) : Color.clear)
            )
            .jiggle(isEditingProjects)
            .contextMenu {
                Button(action: {
                    renameText = room.name
                    renamingRoomID = room.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isRenameFieldFocused = true
                    }
                }) {
                    Label("이름 변경", systemImage: "pencil")
                }
                Button(action: {
                    manager.applyRoomTemplate(.blogWriting, to: room.id)
                }) {
                    Label("콘텐츠 초안 보조", systemImage: "doc.text.magnifyingglass")
                }
                if room.effectiveProfile.mode != .general {
                    Button(action: {
                        manager.applyRoomTemplate(.general, to: room.id)
                    }) {
                        Label("일반 대화방으로 전환", systemImage: "bubble.left")
                    }
                }
                Divider()
                Button(role: .destructive, action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.deleteRoom(id: room.id)
                        if agentRoomID == room.id {
                            agentRoomID = agentRooms.first(where: { $0.id != room.id })?.id
                        }
                    }
                }) {
                    Label("삭제", systemImage: "trash")
                }
            }

            // 삭제 X 버튼 (편집 모드)
            if isEditingProjects && !isSidebarCollapsed {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.deleteRoom(id: room.id)
                        if agentRoomID == room.id {
                            agentRoomID = agentRooms.first(where: { $0.id != room.id })?.id
                        }
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).frame(width: 10, height: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: 4, y: -4)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - 채팅 로그
    private var chatLogView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        // 첫 채팅일 때: 개인 대화창은 간단한 힌트만, 팀 워크룸만 온보딩 카드/액션 표시
                        if chatHistory.isEmpty {
                            if isPersonalChat {
                                // 개인 대화창: 불필요한 온보딩/스파클 없이 한 줄 안내만
                                Text("\(currentAgent.name)에게 바로 말을 걸 수 있어요.")
                                    .font(.system(size: 13))
                                    .foregroundColor(textColor.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 48)
                            } else {
                                VStack(spacing: 16) {
                                    let hasAnyAPIKey = KeychainManager.load(key: "claudeAPIKey") != nil ||
                                                       KeychainManager.load(key: "geminiAPIKey") != nil ||
                                                       KeychainManager.load(key: "openAIAPIKey") != nil ||
                                                       KeychainManager.load(key: "openRouterAPIKey") != nil
                                    let firstLaunchState = FirstLaunchStateProvider.currentState(
                                        hasAPIKey: hasAnyAPIKey
                                    )

                                    if firstLaunchState.shouldShowOnboarding {
                                        // 온보딩 카드 1개만 (배너+카드 동시 표시 없음)
                                        OnboardingCardView(
                                            state: firstLaunchState,
                                            onDismiss: {
                                                FirstLaunchStateProvider.markOnboardingSeen()
                                            },
                                            onOpenSettings: {
                                                manager.showSettingsWindow()
                                            }
                                        )
                                    } else {
                                        // 온보딩 완료 후: 인사말 + 액션
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 32))
                                            .foregroundColor(currentAgent.color)

                                        Text("\(currentAgent.name)와 대화를 시작해 보세요")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(textColor)

                                        starterActionsStripView
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        } else {
                            ForEach(Array(chatHistory.enumerated()), id: \.element.id) { index, log in
                                if index == 0 || !Calendar.current.isDate(
                                    log.timestamp, inSameDayAs: chatHistory[index - 1].timestamp
                                ) {
                                    DateSeparator(date: log.timestamp)
                                }

                                deletableMessageBubble(log: log)
                                    .id(log.id)
                            }

                            // ── 첫 아티팩트 생성 후 "다음 단계" 액션 표시 (room-scoped) ──
                            // 회의록/보고서/체크리스트 등이 생성되면 요약/표로 변경/체크리스트로 변경/Finder 열기 등의 다음 액션 제안
                            if !manager.recentArtifacts(for: agentRoomID ?? UUID()).isEmpty {
                                Divider()
                                    .padding(.vertical, 12)

                                FirstResultActionStripView(
                                    actions: StarterActionProvider.actionsForFirstResult(),
                                    onActionTap: { action in
                                        dispatchStarterAction(action)
                                    }
                                )
                            }
                        }

                        // 타이핑 인디케이터 ("..." 애니메이션)
                        if let typingID = typingAgentID {
                            TypingIndicatorView(
                                agentName: manager.activeAgents.first(where: { $0.id == typingID })?.name ?? "...",
                                agentColor: manager.activeAgents.first(where: { $0.id == typingID })?.color ?? .gray
                            )
                            .id("typing_indicator")
                            .transition(.opacity)
                        }

                        Color.clear.frame(height: 8).id("bottom_anchor")
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .onChange(of: chatHistory.count) { oldCount, newCount in
                    if newCount > oldCount {
                        withAnimation { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                    }
                }
                .onChange(of: speechManager.recognizedText) { _, newText in
                    if speechManager.isRecording {
                        let prefix = preRecordText.isEmpty ? "" : preRecordText + " "
                        inputText = prefix + newText
                    }
                }
            }
            .background(bgColor)

            Divider().background(dividerColor)
            inputFieldView
        }
    }

    @ViewBuilder
    private func deletableMessageBubble(log: AgentWindowManager.ChatLog) -> some View {
        ZStack(alignment: .topTrailing) {
            bubbleContent(for: log)
            .jiggle(isEditingMessages)
            .padding(.trailing, isEditingMessages ? 12 : 0)

            // 삭제 버튼 (항상 우측)
            if isEditingMessages, let roomID = agentRoomID {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.deleteMessage(roomID: roomID, messageID: log.id)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).frame(width: 12, height: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: -4, y: 0)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func bubbleContent(for log: AgentWindowManager.ChatLog) -> some View {
        // Skill result: use skill-specific rendering with custom wrapping
        if log.skillID != nil {
            HStack(alignment: .bottom, spacing: 8) {
                if !log.isUser {
                    Image(systemName: "function")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.green.opacity(0.8))
                } else {
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 3) {
                    if !log.isUser {
                        Text(log.agentName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green.opacity(0.9))
                    }

                    SkillResultRendererView(
                        skillID: log.skillID,
                        text: log.text,
                        isDarkMode: manager.isDarkMode,
                        isUser: log.isUser
                    )

                    if let ts = Optional(log.timestamp) {
                        Text(ts, style: .time)
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }

                if log.isUser { Spacer().frame(width: 8) }
            }
        } else if WorkResultCardView.shouldRenderAsWorkResult(log.text, isUser: log.isUser) {
            // WP2-lite: 긴 어시스턴트 응답 → 전체 너비 업무 결과 카드
            let relatedArtifacts = artifactsForLog(log, roomID: agentRoomID ?? UUID())
            WorkResultCardView(
                text: log.text,
                agentName: log.agentName,
                agentColor: currentAgent.color,
                isDarkMode: manager.isDarkMode,
                timestamp: log.timestamp,
                sources: log.sources,
                relatedArtifacts: relatedArtifacts
            )
        } else {
            // Regular chat: use standard message bubble
            IMMessageBubble(
                text: log.text,
                isUser: log.isUser,
                agentName: log.isUser ? "나" : log.agentName,
                agentImageName: log.isUser ? "" : (log.agentID == "team_all" ? "" : manager.allAvailableAgents.first(where: { $0.id == log.agentID })?.fallbackImageName ?? currentAgent.fallbackImageName),
                agentColor: log.isUser ? .blue : currentAgent.color,
                isDarkMode: manager.isDarkMode,
                timestamp: log.timestamp,
                sources: log.sources
            )
        }
    }

    // MARK: - 입력창
    private var inputFieldView: some View {
        VStack(spacing: 0) {
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .background(inputBgColor)
                Divider()
            }

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    // 파일 첨부 버튼
                    Button(action: openFilePicker) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 16))
                            .foregroundColor(subTextColor)
                    }
                    .buttonStyle(PlainButtonStyle())

                    TextField("\(currentAgent.name)에게 메시지...", text: $inputText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(textColor)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isTargetedForDrop ? currentAgent.color.opacity(0.15) : inputBgColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isTargetedForDrop ? currentAgent.color : Color.clear, lineWidth: 1.5)
                                )
                        )
                        .onSubmit { sendMessage() }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor((inputText.isEmpty && pendingAttachments.isEmpty) ? subTextColor : currentAgent.color)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(inputText.isEmpty && pendingAttachments.isEmpty)
                }
                if let errorMsg = speechManager.sttError {
                    Text(errorMsg).font(.system(size: 10)).foregroundColor(.red)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12).background(bgColor)
        }
        // 드래그&드롭
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    Task { @MainActor in
                        if let attachment = await loadAttachment(from: url) {
                            pendingAttachments.append(attachment)
                        }
                    }
                }
            }
            return true
        }
    }

    // MARK: - 파일 첨부 헬퍼

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.text, .pdf, .image, .plainText, .data]
        panel.begin { response in
            guard response == .OK else { return }
            Task {
                for url in panel.urls {
                    if let attachment = await loadAttachment(from: url) {
                        _ = await MainActor.run {
                            pendingAttachments.append(attachment)
                        }
                    }
                }
            }
        }
    }

    private func loadAttachment(from url: URL) async -> ChatAttachment? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileName = url.lastPathComponent
        let type = ChatAttachment.AttachmentType.from(fileName: fileName)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let textContent = FileContentExtractor.extractText(from: url)

        return ChatAttachment(
            fileName: fileName,
            fileSize: fileSize,
            type: type,
            textContent: textContent,
            localPath: url.path
        )
    }

    // MARK: - DirectChat Evidence Gate
    /// 개인 채팅에서 ToolEvidenceService/ToolPolicy가 필요한지 판단.
    /// 조건: (a) URL 포함  (b) 첨부파일  (c) 명시적 웹 키워드  (d) 외부 정보 키워드
    /// "알려줘/찾아줘/찾아봐" 단독은 일반 대화로 처리 — 오탐 방지.
    private static func directChatNeedsEvidence(_ text: String, hasAttachments: Bool) -> Bool {
        if hasAttachments { return true }
        let lower = text.lowercased()
        if lower.contains("http://") || lower.contains("https://") { return true }
        // 명시적 웹/검색 의도
        let explicitWebKeywords = ["웹", "검색", "인터넷", "구글"]
        if explicitWebKeywords.contains(where: { lower.contains($0) }) { return true }
        // 시의성 있는 외부 정보 (단독으로도 evidence 필요)
        let externalInfoKeywords = ["최신", "뉴스", "날씨", "주가", "환율", "가격", "버전"]
        if externalInfoKeywords.contains(where: { lower.contains($0) }) { return true }
        return false
    }

    private static func directChatEvidenceReason(_ text: String, hasAttachments: Bool) -> String {
        if hasAttachments { return "attachment" }
        let lower = text.lowercased()
        if lower.contains("http://") || lower.contains("https://") { return "url" }
        let explicitWebKeywords = ["웹", "검색", "인터넷", "구글"]
        if explicitWebKeywords.contains(where: { lower.contains($0) }) { return "explicit_web" }
        return "external_info_keyword"
    }

    // MARK: - Artifact Resolution
    private func artifactsForLog(_ log: AgentWindowManager.ChatLog, roomID: UUID) -> [IndexedArtifact] {
        /// ChatLog.artifactIDs → IndexedArtifact resolve (room-scoped)
        log.artifactIDs.compactMap { artifactID in
            manager.artifact(withID: artifactID, roomID: roomID)
        }
    }

    // MARK: - 프로필/상태
    private var agentStatusView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(currentAgent.fallbackImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            VStack(spacing: 8) {
                Text(currentAgent.name)
                    .font(.system(size: 24, weight: .bold))
                Text(currentAgent.role)
                    .font(.system(size: 14))
                    .foregroundColor(subTextColor)
            }
            Text(UserDefaults.standard.string(forKey: "custom_persona_\(currentAgent.id)") ?? currentAgent.role)
                .font(.system(size: 13))
                .foregroundColor(textColor.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(bgColor)
    }

    // MARK: - StarterAction 브리지 (AgentChatView+StarterActions.swift에서 접근)
    // private 메서드를 extension에서 호출할 수 있도록 내부 래퍼 제공
    func _sendStarterPrompt(_ prompt: String) {
        inputText = prompt
        sendMessage()
    }

    func _openFileIntake() {
        openFilePicker()
    }

    func _ensureRoomID() -> UUID? {
        let targetID = activeAgentID ?? config.id
        if let rid = agentRoomID { return rid }
        let agentName = manager.activeAgents.first(where: { $0.id == targetID })?.name
            ?? manager.allAvailableAgents.first(where: { $0.id == targetID })?.name
            ?? config.name
        manager.createAgentRoom(name: "\(agentName) 대화 1", agentID: targetID)
        let newRoomID = manager.rooms.last(where: {
            $0.agentIDs.count == 1 && $0.agentIDs[0] == targetID
        })?.id
        agentRoomID = newRoomID
        return newRoomID
    }

    // MARK: - 메시지 전송
    private func sendMessage() {
        guard !inputText.isEmpty || !pendingAttachments.isEmpty else { return }
        isEditingMessages = false

        let text = inputText
        let attachments = pendingAttachments
        let targetID = activeAgentID ?? config.id
        // agentRoomID nil이면 개인방 생성 — currentRoomID fallback 금지
        let roomID: UUID
        if let rid = agentRoomID {
            roomID = rid
        } else {
            let agentName = manager.activeAgents.first(where: { $0.id == targetID })?.name
                ?? manager.allAvailableAgents.first(where: { $0.id == targetID })?.name
                ?? config.name
            manager.createAgentRoom(name: "\(agentName) 대화 1", agentID: targetID)
            guard let newRoomID = manager.rooms.last(where: {
                $0.agentIDs.count == 1 && $0.agentIDs[0] == targetID
            })?.id else { return }
            agentRoomID = newRoomID
            roomID = newRoomID
        }

        inputText = ""
        pendingAttachments = []

        Task {
            if await ConversationMemory.handleChatCommand(
                text,
                roomID: roomID,
                manager: manager,
                currentAgent: currentAgent
            ) {
                return
            }
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") else { return }

        // 첨부파일 컨텍스트를 메시지에 포함
        let attachmentContext = ConversationMemory.buildAttachmentContext(from: attachments)
        let fullText = attachmentContext.isEmpty ? text : text + attachmentContext

        manager.addChatLog(
            roomID: roomID, agentID: targetID, agentName: "나",
            text: text.isEmpty ? "[첨부파일 \(attachments.count)개]" : text,
            isUser: true
        )

        Task {
            if targetID == "team_all" {
                // ── 팀 채팅: TeamOrchestrator (LLM Selector 기반 유기적 토의) ──
                // activeAgents(화면의 4명)만 참여
                await TeamOrchestrator.shared.runTeamDiscussion(
                    userMessage: fullText,
                    roomID: roomID,
                    manager: manager
                )
            } else {
                // ── 개별 채팅: 해당 에이전트 단독 응답 ──
                // WorkflowOrchestrator / TeamOrchestrator 호출 금지
                // Selector 호출 금지 — 이 경로는 항상 targetID 에이전트 단독 응답
                AppLog.info("[DirectChat] submit roomID=\(roomID.uuidString.prefix(8)) targetAgentID=\(targetID)")
                var history = manager.rooms.first(where: { $0.id == roomID })?.messages ?? []
                
                // 과거 페르소나 오염 방지를 위한 엄격한 슬라이딩 윈도우 한도 적용 (최신 5개)
                history = Array(history.suffix(5))
                
                // (선택) 여전히 30개 초과 요약 로직이 있다면 태우되, 보통 5개면 안 탐
                history = await ConversationMemory.compactHistory(messages: history)

                do {
                    // DirectChat evidence gate — 명확한 외부 정보 요청일 때만 evidence gather 허용
                    // 조건: URL 포함 / 외부 키워드 / 첨부파일 있음
                    let toolPolicy = ToolPolicy.evaluate(fullText)
                    let needsEvidence = Self.directChatNeedsEvidence(fullText, hasAttachments: !attachments.isEmpty)
                    let toolEvidence: ToolEvidenceResult
                    if needsEvidence {
                        AppLog.info("[DirectChat] evidence enabled reason=\(Self.directChatEvidenceReason(fullText, hasAttachments: !attachments.isEmpty))")
                        toolEvidence = await ToolEvidenceService.gather(for: fullText, policy: toolPolicy)
                    } else {
                        AppLog.info("[DirectChat] evidence skipped (no URL/keyword/attachment)")
                        toolEvidence = .empty
                    }
                    let agentName = manager.activeAgents.first(where: { $0.id == targetID })?.name
                        ?? manager.allAvailableAgents.first(where: { $0.id == targetID })?.name
                        ?? "에이전트"
                    var agentConfig = manager.activeAgents.first(where: { $0.id == targetID })
                        ?? manager.allAvailableAgents.first(where: { $0.id == targetID })
                    // P3 tool-capable 라우팅: tool 사용 시 가장 적합한 provider로 자동 전환
                    if toolPolicy.needsTool, let cfg = agentConfig {
                        let capability: LLMCapability = toolPolicy.needsFinance || toolPolicy.needsWeb ? .webSearch : .toolUse
                        let best = LLMConfigCatalog.shared.routeOrDefault(capability, fallback: cfg.llmProvider)
                        if best != cfg.llmProvider {
                            AppLog.debug("[Router] \(agentName) tool 요청 → \(cfg.llmProvider.displayName) → \(best.displayName) 라우팅")
                            agentConfig = cfg.withProvider(best)
                        }
                    }
                    let personalPolicy = ConversationMemory.buildPersonalResponsePolicy(
                        for: agentConfig,
                        toolPolicy: toolPolicy
                    )
                    let groundedText = fullText
                        + manager.roomProfileContext(roomID: roomID)
                        + manager.persistentContext
                        + personalPolicy
                        + toolEvidence.promptContext

                    AppLog.info("[DirectChat] response targetAgentID=\(targetID) provider=\(agentConfig?.llmProvider.displayName ?? "nil") silentMode=\(manager.isSilentMode)")
                    let roomIDAtSend = roomID
                    let targetIDAtSend = targetID
                    // ── 순차 스트리밍: SpeechManager 백그라운드 위임 ──
                    if manager.isSilentMode {
                        _ = await MainActor.run { manager.typingAgentIDs.insert(targetIDAtSend) }
                        let tokenStream = AIService.shared.getResponseStream(
                            text: groundedText, agentID: targetIDAtSend,
                            chatHistory: history, agentConfig: agentConfig
                        )
                        AppLog.debug("[DirectChat] silent getResponseStream opened targetAgentID=\(targetIDAtSend)")
                        var accumulated = ""
                        for try await token in tokenStream {
                            accumulated += token
                        }
                        _ = await MainActor.run {
                            manager.typingAgentIDs.remove(targetIDAtSend)
                            manager.addChatLog(roomID: roomIDAtSend, agentID: targetIDAtSend, agentName: agentName,
                                               text: accumulated, isUser: false, sources: toolEvidence.sources)
                        }
                    } else {
                        // 1. 타이핑 인디케이터 ON
                        _ = await MainActor.run { manager.typingAgentIDs.insert(targetIDAtSend) }

                        // 2. SSE 스트림 오픈
                        let tokenStream = AIService.shared.getResponseStream(
                            text: groundedText, agentID: targetIDAtSend, chatHistory: history, agentConfig: agentConfig
                        )

                        // 3. SpeechManager에 SSE→오디오 배관 완전 위임
                        SpeechManager.shared.processRealtimeSSEStream(
                            agentID: targetIDAtSend,
                            characterName: agentName,
                            tokenStream: tokenStream,
                            onAudioPlaybackStarted: { chunk in
                                DispatchQueue.main.async {
                                    manager.typingAgentIDs.remove(targetIDAtSend)
                                    manager.addChatLog(roomID: roomIDAtSend, agentID: targetIDAtSend, agentName: agentName,
                                                       text: chunk, isUser: false, sources: toolEvidence.sources)
                                    manager.setAgentSpeaking(agentID: targetIDAtSend, text: chunk)
                                }
                            }
                        )
                    }
                } catch {
                    _ = await MainActor.run {
                        manager.typingAgentIDs.remove(targetID)
                        manager.addChatLog(roomID: roomID, agentID: "system", agentName: "시스템", text: error.localizedDescription, isUser: false)
                    }
                }
            }
        }
    }
}
