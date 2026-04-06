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
        let roomID = agentRoomID ?? manager.currentRoomID
        let logs = manager.rooms.first(where: { $0.id == roomID })?.messages ?? []
        let targetID = activeAgentID ?? config.id
        if isPersonalChat {
            return logs.filter { $0.agentID == targetID || $0.isUser }
        } else {
            return logs
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
    private var subTextColor: Color { manager.isDarkMode ? .white.opacity(0.45) : .black.opacity(0.35) }
    private var dividerColor: Color { manager.isDarkMode ? .white.opacity(0.07) : .black.opacity(0.06) }
    private var inputBgColor: Color { manager.isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04) }

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
            if let firstRoom = agentRooms.first {
                agentRoomID = firstRoom.id
            } else {
                let targetID = config.id
                manager.createAgentRoom(name: "\(config.name) 대화 1", agentID: targetID)
                agentRoomID = manager.rooms.last?.id
            }
            // 초기 창 크기 강제 설정 (SwiftUI 레이아웃 완료 후 실행)
            DispatchQueue.main.async {
                manager.updateChatWindowSize(id: config.id, width: viewWidth, height: 520,
                                              minSize: NSSize(width: 300, height: 480))
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
                        if let newRoom = manager.rooms.last {
                            agentRoomID = newRoom.id
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
                    let roomID = agentRoomID ?? manager.currentRoomID
                    if let room = manager.rooms.first(where: { $0.id == roomID }) {
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
                    Text("프로젝트")
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

            Divider().background(dividerColor)

            // 에이전트 전환
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(manager.activeAgents) { agent in
                        Button(action: {
                            withAnimation {
                                activeAgentID = agent.id
                                let rooms = manager.rooms.filter { $0.agentIDs.contains(agent.id) }
                                agentRoomID = rooms.first?.id ?? manager.currentRoomID
                            }
                            isEditingProjects = false
                        }) {
                            Image(agent.fallbackImageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                                .font(.system(size: 18))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(activeAgentID == agent.id ? agent.color.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
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
                    Image(systemName: "bubble.left.fill")
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
                            if let lastMsg = room.messages.last, !isRenaming {
                                Text(lastMsg.text)
                                    .font(.system(size: 9))
                                    .foregroundColor(subTextColor)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if !isRenaming {
                            let count = room.messages.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(isSelected ? currentAgent.color : Color.gray.opacity(0.3)))
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
                        ForEach(Array(chatHistory.enumerated()), id: \.element.id) { index, log in
                            if index == 0 || !Calendar.current.isDate(
                                log.timestamp, inSameDayAs: chatHistory[index - 1].timestamp
                            ) {
                                DateSeparator(date: log.timestamp)
                            }

                            deletableMessageBubble(log: log)
                                .id(log.id)
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
            IMMessageBubble(
                text: log.text,
                isUser: log.isUser,
                agentName: log.isUser ? "나" : log.agentName,
                agentImageName: log.isUser ? "" : (log.agentID == "team_all" ? "" : manager.allAvailableAgents.first(where: { $0.id == log.agentID })?.fallbackImageName ?? currentAgent.fallbackImageName),
                agentColor: log.isUser ? .blue : currentAgent.color,
                isDarkMode: manager.isDarkMode,
                timestamp: log.timestamp
            )
            .jiggle(isEditingMessages)
            .padding(.trailing, isEditingMessages ? 12 : 0)

            // 삭제 버튼 (항상 우측)
            if isEditingMessages {
                let roomID = agentRoomID ?? manager.currentRoomID
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        if let rID = roomID {
                            manager.deleteMessage(roomID: rID, messageID: log.id)
                        }
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
                .background(inputBgColor.opacity(0.5))
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
                        await MainActor.run {
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

    // MARK: - 메시지 전송
    private func sendMessage() {
        guard !inputText.isEmpty || !pendingAttachments.isEmpty else { return }
        isEditingMessages = false

        let text = inputText
        let attachments = pendingAttachments
        let targetID = activeAgentID ?? config.id
        let roomID = agentRoomID ?? manager.currentRoomID

        inputText = ""
        pendingAttachments = []

        // 첨부파일 컨텍스트를 메시지에 포함
        let attachmentContext = ConversationMemory.buildAttachmentContext(from: attachments)
        let fullText = attachmentContext.isEmpty ? text : text + attachmentContext

        manager.addChatLog(
            agentID: targetID, agentName: "나",
            text: text.isEmpty ? "[첨부파일 \(attachments.count)개]" : text,
            isUser: true, roomID: roomID
        )

        Task {
            if targetID == "team_all" {
                // ── 팀 채팅: TeamOrchestrator (LLM Selector 기반 유기적 토의) ──
                // activeAgents(화면의 4명)만 참여
                await TeamOrchestrator.shared.runTeamDiscussion(
                    userMessage: fullText,
                    roomID: roomID ?? UUID(),
                    manager: manager
                )
            } else {
                // ── 개별 채팅: 해당 에이전트 단독 응답 ──
                var history = manager.rooms.first(where: { $0.id == roomID })?.messages ?? []
                
                // 과거 페르소나 오염 방지를 위한 엄격한 슬라이딩 윈도우 한도 적용 (최신 5개)
                history = Array(history.suffix(5))
                
                // (선택) 여전히 30개 초과 요약 로직이 있다면 태우되, 보통 5개면 안 탐
                history = await ConversationMemory.compactHistory(messages: history)

                do {
                    let (responseText, _) = try await AIService.shared.getResponse(
                        text: fullText, agentID: targetID, chatHistory: history
                    )
                    let agentName = manager.activeAgents.first(where: { $0.id == targetID })?.name
                        ?? manager.allAvailableAgents.first(where: { $0.id == targetID })?.name
                        ?? "에이전트"

                    let chunks = Self.splitIntoMessageChunks(responseText)

                    // ── 순차 스트리밍: 청크별 TTS + 말풍선 동기화 ──
                    if manager.isSilentMode {
                        // 무음 모드: 타이핑 딜레이만 넣고 순차 표시
                        for chunk in chunks {
                            await MainActor.run { manager.typingAgentIDs.insert(targetID) }
                            try? await Task.sleep(nanoseconds: UInt64.random(in: 800_000_000...1_500_000_000))
                            await MainActor.run {
                                manager.typingAgentIDs.remove(targetID)
                                manager.addChatLog(agentID: targetID, agentName: agentName,
                                                   text: chunk, isUser: false, roomID: roomID)
                            }
                        }
                    } else {
                        // TTS 모드: 순차 합성+재생 + 다음 청크 미리 굽기
                        for (i, chunk) in chunks.enumerated() {
                            // 다음 청크 pre-fetch (현재 청크와 병렬)
                            if i + 1 < chunks.count {
                                SpeechManager.shared.prefetchChunk(
                                    text: chunks[i + 1], characterName: agentName)
                            }

                            await MainActor.run {
                                manager.typingAgentIDs.insert(targetID)
                                if i == 0 {
                                    manager.setAgentSpeaking(agentID: targetID, text: responseText)
                                }
                            }

                            let success = await SpeechManager.shared.speakChunk(
                                text: chunk, agentID: targetID, characterName: agentName,
                                onStart: {
                                    // 오디오 시작 = 말풍선 표시
                                    manager.typingAgentIDs.remove(targetID)
                                    manager.addChatLog(agentID: targetID, agentName: agentName,
                                                       text: chunk, isUser: false, roomID: roomID)
                                }
                            )
                            if !success {
                                // TTS 실패 시 텍스트만이라도 표시
                                await MainActor.run {
                                    manager.typingAgentIDs.remove(targetID)
                                    manager.addChatLog(agentID: targetID, agentName: agentName,
                                                       text: chunk, isUser: false, roomID: roomID)
                                }
                            }
                            // 말풍선 간 자연 간격
                            if i < chunks.count - 1 {
                                try? await Task.sleep(nanoseconds: UInt64.random(in: 300_000_000...600_000_000))
                            }
                        }
                        await MainActor.run { manager.clearAgentSpeaking(agentID: targetID) }
                    }
                } catch {
                    await MainActor.run {
                        manager.typingAgentIDs.remove(targetID)
                        manager.addChatLog(agentID: targetID, agentName: "시스템", text: error.localizedDescription, isUser: false, roomID: roomID)
                    }
                }
            }
        }
    }

    // MARK: - 카톡 스타일 메시지 분리
    // 글자 수 25자 상한 + 문장 경계 존중 → TTS 합성 1초 이내 보장
    static func splitIntoMessageChunks(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let sentences = splitSentences(trimmed)
        guard !sentences.isEmpty else { return [trimmed] }

        var chunks: [String] = []
        var buffer = ""
        let maxChars = 25  // TTS 속도 1초 이내 보장

        for sentence in sentences {
            // 현재 버퍼 + 이 문장이 25자 초과하면 버퍼 flush
            if !buffer.isEmpty && (buffer.count + sentence.count + 1) > maxChars {
                chunks.append(buffer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                buffer = ""
            }
            // 문장 자체가 25자 초과 → 그대로 하나의 청크 (더 쪼개면 의미 깨짐)
            if buffer.isEmpty && sentence.count > maxChars {
                chunks.append(sentence.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                continue
            }
            buffer += (buffer.isEmpty ? "" : " ") + sentence
        }
        if !buffer.isEmpty {
            chunks.append(buffer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        }

        let result = chunks.filter { !$0.isEmpty }
        return result.isEmpty ? [trimmed] : result
    }

    private static func splitSentences(_ text: String) -> [String] {
        // 한국어/영어 문장 종결 패턴으로 분리
        var sentences: [String] = []
        let pattern = try? NSRegularExpression(pattern: "(?<=[.!?。！？~])(\\s+|(?=[가-힣A-Z\"']))", options: [])
        guard let regex = pattern else { return [text] }

        let nsText = text as NSString
        var lastEnd = 0
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let splitPoint = match.range.location + match.range.length
            if splitPoint > lastEnd {
                let sentence = nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd + 1))
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !sentence.isEmpty { sentences.append(sentence) }
                lastEnd = splitPoint
            }
        }

        // 마지막 문장
        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !remaining.isEmpty { sentences.append(remaining) }
        }

        return sentences.isEmpty ? [text] : sentences
    }
}

