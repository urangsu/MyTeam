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
    @State private var attachmentError: String? = nil
    @State private var isQuickActionMenuPresented: Bool = false

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
                manager.createAgentRoom(name: "기본 대화", agentID: targetID)
                // last?.id 대신 agentID로 정확히 찾아 오염 방지
                agentRoomID = manager.rooms.last(where: {
                    $0.agentIDs.count == 1 && $0.agentIDs[0] == targetID
                })?.id
            }
            // 초기 창 크기 강제 설정 (SwiftUI 레이아웃 완료 후 실행)
            DispatchQueue.main.async {
                if manager.savedChatWindowSize() == nil {
                    manager.updateChatWindowSize(id: config.id, width: viewWidth, height: 520,
                                                  minSize: NSSize(width: 520, height: 480))
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if !isMinimized {
                let w = newValue == 0 ? 300 : viewWidth
                DispatchQueue.main.async {
                    manager.updateChatWindowWidth(id: config.id, width: max(520, w))
                }
            }
        }
        .onChange(of: isSidebarCollapsed) { _, _ in
            if selectedTab == 1 && !isMinimized {
                let w = viewWidth
                DispatchQueue.main.async {
                    manager.updateChatWindowWidth(id: config.id, width: max(520, w))
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
                                                  minSize: NSSize(width: 520, height: 480))
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
                        manager.createAgentRoom(name: "기본 대화", agentID: id)
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
                .help("채팅창 펼치기")
                .accessibilityLabel("채팅창 펼치기")

                // 닫기
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(subTextColor.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .help("채팅창 닫기")
                .accessibilityLabel("채팅창 닫기")
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

            Text(currentAgent.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer()

            HStack(spacing: 11) {
                Button(action: {
                    selectedTab = (selectedTab == 0 ? 1 : 0)
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
                    Menu {
                        Button(isEditingMessages ? "메시지 정리 끝내기" : "메시지 정리") {
                            isEditingMessages.toggle()
                            if isEditingMessages { isEditingProjects = false }
                        }
                        Button(speechManager.isRecording ? "음성 입력 중지" : "음성으로 입력") {
                            toggleVoiceInput()
                        }
                        .disabled(speechManager.isStarting)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(subTextColor)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("대화 도구")
                }

                // 최소화 (팀 협업창 스타일)
                Button(action: {
                    isMinimized = true
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(subTextColor)
                }
                .help("작은 바로 최소화")
                .accessibilityLabel("채팅창 최소화")

                // 닫기
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(subTextColor.opacity(0.6))
                }
                .help("채팅창 닫기")
                .accessibilityLabel("채팅창 닫기")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(bgColor)
    }

    private func toggleVoiceInput() {
        if speechManager.isRecording {
            speechManager.stopRecording()
            return
        }
        speechManager.requestAuthorization { authorized, guidance in
            if authorized {
                preRecordText = inputText
                speechManager.startRecording()
            } else if let guidance, let roomID = agentRoomID {
                manager.addChatLog(
                    roomID: roomID,
                    agentID: "system",
                    agentName: "시스템",
                    text: guidance,
                    isUser: false
                )
            }
        }
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
        let newName = agentRooms.isEmpty ? "기본 대화" : "대화 \(agentRooms.count + 1)"
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
                                Text(KoreanText.personalRoomDisplayName(roomName: room.name, agentName: currentAgent.name))
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? currentAgent.color : textColor.opacity(0.7))
                                    .lineLimit(1)
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
                                    let hasAnyAPIKey = SecureCredentialStore.shared.hasAnyAIProviderKey()
                                    let firstLaunchState = FirstLaunchStateProvider.currentState(
                                        hasAPIKey: hasAnyAPIKey
                                    )

                                    if firstLaunchState.shouldShowOnboarding {
                                        FirstLaunchOnboardingFlowView(
                                            manager: manager,
                                            onOpenSettings: { manager.showSettingsWindow() }
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
            // Round 247A: Pending observation inbox (개인 대화, agentRoomID 기준)
            // selectedTeamWorkroomID 사용 금지, 팀 워크룸 observation 표시 금지
            if let personalRoomID = agentRoomID {
                ObservationInboxView(
                    roomID: personalRoomID,
                    observationService: manager.observationService,
                    onAnalyze: { obs in manager.analyzeObservation(obs, in: personalRoomID) },
                    onIgnore: { obs in manager.ignoreObservation(obs) }
                )
            }
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

            // 말하기 버튼 (Supertonic3) — 비편집 모드, 비사용자 메시지만
            if !isEditingMessages && !log.isUser && !log.text.isEmpty && TTSRoutingPolicy.isSupertonic3Available {
                SpeakButtonView(
                    text: log.text,
                    agentID: log.agentID
                )
                .offset(x: 0, y: -2)
                .transition(.opacity)
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

                    CopyableMessageContainer(text: log.text, isUser: log.isUser) {
                        SkillResultRendererView(
                            skillID: log.skillID,
                            text: log.text,
                            isDarkMode: manager.isDarkMode,
                            isUser: log.isUser
                        )
                    }

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
            CopyableMessageContainer(text: log.text, isUser: false) {
                WorkResultCardView(
                    text: log.text,
                    agentName: log.agentName,
                    agentColor: currentAgent.color,
                    isDarkMode: manager.isDarkMode,
                    timestamp: log.timestamp,
                    sources: log.sources,
                    relatedArtifacts: relatedArtifacts
                )
            }
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
                sources: log.sources,
                enableTypewriter: shouldTypewriteMessage(log)
            )
        }
    }

    private func shouldTypewriteMessage(_ log: AgentWindowManager.ChatLog) -> Bool {
        let isLegacyLocalLine = log.presentationStyle == nil
            && (log.agentID == "system" || log.isSystem)
        guard log.presentationStyle == .casualTypewriter || isLegacyLocalLine else { return false }
        return ChatTypingPolicy.shouldAnimate(
            text: log.text,
            isUser: log.isUser,
            isSkillResult: log.skillID != nil
        )
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
                    .help("파일 첨부")
                    .accessibilityLabel("파일 첨부")

                    Button(action: { isQuickActionMenuPresented.toggle() }) {
                        Image(systemName: "scroll")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(currentAgent.color)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $isQuickActionMenuPresented, arrowEdge: .bottom) {
                        QuickActionMenuContent(
                            isDark: manager.isDarkMode,
                            onPrompt: { prompt in
                                isQuickActionMenuPresented = false
                                inputText = prompt
                            },
                            onFileIntake: {
                                isQuickActionMenuPresented = false
                                openFilePicker()
                            }
                        )
                        .frame(width: 300, height: 420)
                    }
                    .help("빠른 지시")
                    .accessibilityLabel("빠른 지시")

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
                    .help("메시지 보내기")
                    .accessibilityLabel("메시지 보내기")
                }
                if let errorMsg = speechManager.sttError {
                    Text(errorMsg).font(.system(size: 10)).foregroundColor(.red)
                }
                if let attachmentError {
                    Text(attachmentError).font(.system(size: 10)).foregroundColor(.red)
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

    // MARK: - 파일 첨부 헬퍼

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.allowedAttachmentContentTypes
        panel.begin { response in
            guard response == .OK else { return }
            Task {
                for url in panel.urls {
                    if let attachment = await loadAttachment(from: url) {
                        _ = await MainActor.run {
                            pendingAttachments.append(attachment)
                            attachmentError = nil
                        }
                    } else {
                        _ = await MainActor.run {
                            attachmentError = "첨부를 읽지 못했어요. 파일 권한이나 형식을 확인해 주세요."
                        }
                    }
                }
            }
        }
    }

    private func loadAttachment(from url: URL) async -> ChatAttachment? {
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

        return ChatAttachment(
            fileName: fileName,
            fileSize: fileSize,
            type: type,
            textContent: textContent,
            localPath: url.path
        )
    }

    private static var allowedAttachmentContentTypes: [UTType] {
        var types: [UTType] = [.text, .plainText, .pdf, .image, .data]
        let extensions = ["md", "markdown", "csv", "xlsx", "docx", "pptx", "hwp", "hwpx"]
        types.append(contentsOf: extensions.compactMap { UTType(filenameExtension: $0) })
        return types
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

    func _prefillStarterPrompt(_ prompt: String) {
        inputText = prompt
    }

    func _openFileIntake() {
        openFilePicker()
    }

    func _ensureRoomID() -> UUID? {
        let targetID = activeAgentID ?? config.id
        if let rid = agentRoomID { return rid }
        manager.createAgentRoom(name: "기본 대화", agentID: targetID)
        let newRoomID = manager.rooms.last(where: {
            $0.agentIDs.count == 1 && $0.agentIDs[0] == targetID
        })?.id
        agentRoomID = newRoomID
        return newRoomID
    }

    @MainActor
    private func setTyping(_ targetID: String, _ isTyping: Bool) {
        if isTyping {
            manager.typingAgentIDs.insert(targetID)
        } else {
            manager.typingAgentIDs.remove(targetID)
        }
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
            manager.createAgentRoom(name: "기본 대화", agentID: targetID)
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

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") else { return }

            // 첨부파일 컨텍스트를 메시지에 포함
            let attachmentContext = ConversationMemory.buildAttachmentContext(from: attachments)
            let fullText = attachmentContext.isEmpty ? text : text + attachmentContext
            let naturalSnapshot = await MainActor.run {
                NaturalWorkContextProvider.snapshot(
                    roomID: roomID,
                    manager: manager,
                    pendingAttachments: attachments
                )
            }

            let userMessageID = await MainActor.run {
                manager.addChatLog(
                    roomID: roomID, agentID: targetID, agentName: "나",
                    text: text.isEmpty ? "[첨부파일 \(attachments.count)개]" : text,
                    isUser: true
                )
            }

            let pendingResolution = await MainActor.run {
                PendingNaturalWorkCoordinator.resolve(
                    userMessage: text,
                    roomID: roomID,
                    manager: manager
                )
            }
            guard let naturalRouteText = pendingResolution.routeText else {
                return
            }

            switch await NaturalWorkEntryPoint.resolve(
                text: naturalRouteText,
                context: naturalSnapshot.context,
                chatHistory: naturalSnapshot.chatHistory,
                agentID: targetID,
                agentConfig: currentAgent
            ) {
            case .clarification(let request):
                await MainActor.run {
                    PendingNaturalWorkCoordinator.storeClarification(
                        request,
                        roomID: roomID,
                        manager: manager
                    )
                }
                return
            case .plan(let naturalPlan):
                if targetID != "team_all" {
                    setTyping(targetID, true)
                }
                _ = await NaturalWorkPlanRunner.run(
                    naturalPlan,
                    originalText: fullText,
                    roomID: roomID,
                    manager: manager,
                    shouldClearPending: pendingResolution.shouldClearAfterPlan,
                    path: .chatFastPath
                )
                if targetID != "team_all" {
                    setTyping(targetID, false)
                }
                return
            case .unsupported(let reason):
                _ = await MainActor.run {
                    manager.addChatLog(
                        roomID: roomID,
                        agentID: "system",
                        agentName: "업무 실행",
                        text: reason,
                        isUser: false
                    )
                }
                return
            case .fallback:
                break
            }

            if await LegacyWorkflowFallbackRouter.shared.handle(
                text: naturalRouteText,
                roomID: roomID,
                manager: manager,
                path: .chatFastPath
            ) {
                if targetID != "team_all" {
                    await MainActor.run {
                        _ = manager.typingAgentIDs.remove(targetID)
                    }
                }
                return
            }

            if targetID == "team_all" {
                let matchedSkills = SkillRegistry.shared.matchEnabledSkills(for: fullText)
                let skillRoute = await SkillOrchestrator.route(
                    message: fullText,
                    roomID: roomID,
                    attachments: attachments,
                    agentID: targetID,
                    matchedSkills: matchedSkills
                )
                if let skillRoute {
                    let artifact = await KSkillRunEngine.writeResultArtifact(
                        skillRoute.result,
                        roomID: roomID,
                        manager: manager
                    )
                    var responseText = skillRoute.result.markdown
                    if let artifact {
                        responseText += """

                        ---
                        결과 카드를 이 방에 저장했습니다.
                        파일: \(artifact.filename)
                        """
                    }
                    _ = await MainActor.run {
                        manager.addChatLog(
                            roomID: roomID,
                            agentID: "system",
                            agentName: skillRoute.result.title,
                            text: responseText,
                            isUser: false,
                            sources: skillRoute.evidence.sources,
                            skillID: skillRoute.result.skillID
                        )
                    }
                }
                await TeamOrchestrator.shared.runTeamDiscussion(
                    userMessage: fullText,
                    roomID: roomID,
                    manager: manager,
                    currentUserMessageID: userMessageID,
                    chainRunID: skillRoute?.result.chainRunID,
                    chainEvidence: skillRoute?.evidence
                )
            } else {
                // ── 개별 채팅: 해당 에이전트 단독 응답 ──
                // WorkflowOrchestrator / TeamOrchestrator 호출 금지
                // Selector 호출 금지 — 이 경로는 항상 targetID 에이전트 단독 응답
                setTyping(targetID, true)
                AppLog.info("[DirectChat] submit roomID=\(roomID.uuidString.prefix(8)) targetAgentID=\(targetID)")
                let roomMessages = manager.rooms.first(where: { $0.id == roomID })?.messages ?? []
                var history = ConversationMemory.promptHistory(
                    messages: roomMessages,
                    excludingMessageID: userMessageID,
                    maxMessages: 5
                )
                
                // (선택) 여전히 30개 초과 요약 로직이 있다면 태우되, 보통 5개면 안 탐
                history = await ConversationMemory.compactHistory(messages: history)

                let matchedSkills = SkillRegistry.shared.matchEnabledSkills(for: fullText)
                if let skillRoute = await SkillOrchestrator.route(
                    message: fullText,
                    roomID: roomID,
                    attachments: attachments,
                    agentID: targetID,
                    matchedSkills: matchedSkills
                ) {
                    let artifact = await KSkillRunEngine.writeResultArtifact(
                        skillRoute.result,
                        roomID: roomID,
                        manager: manager
                    )
                    var responseText = skillRoute.result.markdown
                    if let artifact {
                        responseText += """

                        ---
                        결과 카드를 이 방에 저장했습니다.
                        파일: \(artifact.filename)
                        """
                    }
                    _ = await MainActor.run {
                        manager.addChatLog(
                            roomID: roomID,
                            agentID: "system",
                            agentName: skillRoute.result.title,
                            text: responseText,
                            isUser: false,
                            sources: skillRoute.evidence.sources,
                            skillID: skillRoute.result.skillID
                        )
                    }
                    setTyping(targetID, false)
                    return
                }

                do {
                    // DirectChat evidence gate — 명확한 외부 정보 요청일 때만 evidence gather 허용
                    // 조건: URL 포함 / 외부 키워드 / 첨부파일 있음
                    let toolPolicy = ToolPolicy.evaluate(fullText)
                    let requiresToolUse = toolPolicy.needsTool || RoutingIntentPrecheck.needsTool(
                        fullText,
                        hasAttachments: !attachments.isEmpty
                    )
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
                    let replyMode = ConversationReplyPolicy.mode(
                        for: fullText,
                        forceWork: requiresToolUse || needsEvidence || !attachments.isEmpty
                    )
                    let personalPolicy = ConversationMemory.buildPersonalResponsePolicy(
                        for: agentConfig,
                        toolPolicy: toolPolicy,
                        replyMode: replyMode
                    )
                    let groundedText = """
                    [사용자 발화]
                    \(fullText)

                    [응답 참고 정보 - 사용자 발화가 아님]
                    \(manager.roomProfileContext(roomID: roomID))
                    \(manager.scopedMemoryContext(agentName: agentName, roomID: roomID))
                    \(personalPolicy)
                    \(toolEvidence.promptContext)
                    """

                    let ttsProvider = TTSRoutingPolicy.selectedProvider()
                    AppLog.info("[DirectChat] response targetAgentID=\(targetID) provider=\(agentConfig?.llmProvider.displayName ?? "nil") silentMode=\(manager.isSilentMode) ttsProvider=\(ttsProvider?.rawValue ?? "nil")")
                    let roomIDAtSend = roomID
                    let targetIDAtSend = targetID
                    let llmRequestID = UUID()
                    let sourceSnippetCharacters = toolEvidence.promptContext.count
                    let fileContextCharacters = attachmentContext.count
                    // ── 순차 스트리밍: SpeechManager 백그라운드 위임 ──
                    if manager.isSilentMode || ttsProvider == nil {
                        let tokenStream = AIService.shared.getResponseStream(
                            text: groundedText, agentID: targetIDAtSend,
                            chatHistory: history, agentConfig: agentConfig,
                            requiresToolUse: requiresToolUse,
                            requestID: llmRequestID,
                            toolDescriptorCount: requiresToolUse ? 1 : 0,
                            sourceSnippetCharacters: sourceSnippetCharacters,
                            fileContextCharacters: fileContextCharacters,
                            selectedAgentCount: 1
                        )
                        AppLog.debug("[DirectChat] silent getResponseStream opened targetAgentID=\(targetIDAtSend)")
                        var accumulated = ""
                        var assistantMessageIDs: [UUID] = []
                        for try await token in tokenStream {
                            accumulated += token

                            let visibleSegments = CasualBubbleSegmenter.streamingSegments(
                                from: accumulated,
                                mode: replyMode
                            )
                            guard !visibleSegments.isEmpty else { continue }
                            await MainActor.run {
                                for (index, segment) in visibleSegments.enumerated() {
                                    let segmentSources = index == 0 ? toolEvidence.sources : []
                                    if index < assistantMessageIDs.count {
                                        manager.updateChatLogText(
                                            roomID: roomIDAtSend,
                                            messageID: assistantMessageIDs[index],
                                            text: segment,
                                            sources: segmentSources
                                        )
                                    } else if let messageID = manager.addChatLog(
                                        roomID: roomIDAtSend,
                                        agentID: targetIDAtSend,
                                        agentName: agentName,
                                        text: segment,
                                        isUser: false,
                                        sources: segmentSources
                                    ) {
                                        assistantMessageIDs.append(messageID)
                                    }
                                }
                            }
                        }
                        let executionMetadata = await LLMExecutionTraceStore.shared.metadata(for: llmRequestID)
                        await MainActor.run {
                            manager.typingAgentIDs.remove(targetIDAtSend)
                            if let executionMetadata {
                                for messageID in assistantMessageIDs {
                                    manager.updateChatLogLLMMetadata(
                                        roomID: roomIDAtSend,
                                        messageID: messageID,
                                        metadata: executionMetadata
                                    )
                                }
                            }
                            if assistantMessageIDs.isEmpty {
                                manager.addChatLog(
                                    roomID: roomIDAtSend,
                                    agentID: "system",
                                    agentName: "시스템",
                                    text: "응답이 비어 있습니다. API 키와 모델 설정을 확인해 주세요.",
                                    isUser: false
                                )
                            }
                        }
                    } else {
                        // SSE 스트림 오픈. 화면에는 LLM 원문을 누적 표시하고,
                        // TTS에는 별도 proxy stream을 넘긴다. TTS chunk truncation이 채팅 로그를 훼손하면 안 된다.
                        let sourceStream = AIService.shared.getResponseStream(
                            text: groundedText, agentID: targetIDAtSend, chatHistory: history, agentConfig: agentConfig,
                            requiresToolUse: requiresToolUse,
                            requestID: llmRequestID,
                            toolDescriptorCount: requiresToolUse ? 1 : 0,
                            sourceSnippetCharacters: sourceSnippetCharacters,
                            fileContextCharacters: fileContextCharacters,
                            selectedAgentCount: 1
                        )
                        let ttsStream = AsyncThrowingStream<String, Error> { continuation in
                            let relayTask = Task {
                                var accumulated = ""
                                var assistantMessageIDs: [UUID] = []
                                do {
                                    for try await token in sourceStream {
                                        accumulated += token
                                        continuation.yield(token)

                                        let visibleSegments = CasualBubbleSegmenter.streamingSegments(
                                            from: accumulated,
                                            mode: replyMode
                                        )
                                        guard !visibleSegments.isEmpty else { continue }
                                        await MainActor.run {
                                            for (index, segment) in visibleSegments.enumerated() {
                                                let segmentSources = index == 0 ? toolEvidence.sources : []
                                                if index < assistantMessageIDs.count {
                                                    manager.updateChatLogText(
                                                        roomID: roomIDAtSend,
                                                        messageID: assistantMessageIDs[index],
                                                        text: segment,
                                                        sources: segmentSources
                                                    )
                                                } else if let messageID = manager.addChatLog(
                                                    roomID: roomIDAtSend,
                                                    agentID: targetIDAtSend,
                                                    agentName: agentName,
                                                    text: segment,
                                                    isUser: false,
                                                    sources: segmentSources
                                                ) {
                                                    assistantMessageIDs.append(messageID)
                                                }
                                            }
                                        }
                                    }
                                    continuation.finish()
                                    let executionMetadata = await LLMExecutionTraceStore.shared.metadata(for: llmRequestID)
                                    await MainActor.run {
                                        manager.typingAgentIDs.remove(targetIDAtSend)
                                        if let executionMetadata {
                                            for messageID in assistantMessageIDs {
                                                manager.updateChatLogLLMMetadata(
                                                    roomID: roomIDAtSend,
                                                    messageID: messageID,
                                                    metadata: executionMetadata
                                                )
                                            }
                                        }
                                        if assistantMessageIDs.isEmpty {
                                            manager.addChatLog(
                                                roomID: roomIDAtSend,
                                                agentID: "system",
                                                agentName: "시스템",
                                                text: "응답이 비어 있습니다. API 키와 모델 설정을 확인해 주세요.",
                                                isUser: false
                                            )
                                        }
                                    }
                                } catch {
                                    continuation.finish(throwing: error)
                                    await MainActor.run {
                                        manager.typingAgentIDs.remove(targetIDAtSend)
                                        manager.addChatLog(
                                            roomID: roomIDAtSend,
                                            agentID: "system",
                                            agentName: "시스템",
                                            text: AIErrorPresentation.userMessage(for: error),
                                            isUser: false
                                        )
                                    }
                                }
                            }
                            continuation.onTermination = { @Sendable _ in
                                relayTask.cancel()
                            }
                        }

                        // 3. SpeechManager는 오디오용 proxy stream만 소비한다.
                        SpeechManager.shared.processRealtimeSSEStream(
                            agentID: targetIDAtSend,
                            characterName: agentName,
                            tokenStream: ttsStream,
                            replyMode: replyMode
                        )
                    }
                } catch {
                    _ = await MainActor.run {
                        manager.typingAgentIDs.remove(targetID)
                        manager.addChatLog(
                            roomID: roomID,
                            agentID: "system",
                            agentName: "시스템",
                            text: AIErrorPresentation.userMessage(for: error),
                            isUser: false
                        )
                    }
                }
            }
        }
    }
}

// MARK: - SpeakButtonView (Round 257TTS-PLAYBACK)
/// 작은 말하기 버튼 — 비사용자 메시지에 오버레이.
/// 클릭 시 SpeechManager.speakOnce → Supertonic3 합성 + AudioPlaybackService 재생.
/// 자동 재생 없음 — 사용자 명시 클릭 시만 동작.
private struct SpeakButtonView: View {
    let text: String
    let agentID: String?

    @State private var isSynthesizing: Bool = false
    @State private var hasPlayed: Bool = false      // 재생 성공 여부 (아이콘 상태)
    @State private var errorMessage: String? = nil

    private var isAvailable: Bool {
        TTSRoutingPolicy.isSupertonic3Available
    }

    var body: some View {
        HStack(spacing: 3) {
            if isSynthesizing {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 14, height: 14)
            } else {
                Button {
                    speakOnce()
                } label: {
                    Image(systemName: hasPlayed ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 11))
                        .foregroundStyle(
                            errorMessage != nil
                                ? Color.red.opacity(0.7)
                                : isAvailable
                                    ? Color.accentColor.opacity(0.7)
                                    : Color.secondary.opacity(0.4)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable || isSynthesizing)
                .help(
                    errorMessage != nil
                        ? "재생 실패 — 모델 파일·ONNX Runtime·고지 수락 확인 필요"
                        : isAvailable
                            ? "말하기 (Supertonic3)"
                            : "Supertonic3 미사용 가능 — 모델·고지·활성화 확인 필요"
                )
            }
        }
        .padding(3)
    }

    /// 합성 + 재생. SpeechManager.speakOnce가 playerNode.play() 이후 반환.
    private func speakOnce() {
        isSynthesizing = true
        errorMessage = nil
        Task {
            let output = await SpeechManager.shared.speakOnce(text: text, agentID: agentID)
            await MainActor.run {
                isSynthesizing = false
                if output != nil {
                    hasPlayed = true
                    errorMessage = nil
                } else {
                    errorMessage = "재생 실패 또는 TTS 미설정"
                }
            }
        }
    }
}
