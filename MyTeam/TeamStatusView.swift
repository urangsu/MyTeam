import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - TeamStatusView
// 고도화: 팀 전체 채팅방(Logs) + 사운드/무음 모드 토글 + 다크모드
struct TeamStatusView: View {
    @EnvironmentObject var manager: AgentWindowManager
    @State private var isCollapsed = false
    @State private var selectedTab: Int = 0
    @State private var isDeleteMode = false
    @State private var roomToDelete: AgentWindowManager.ChatRoom? = nil
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var roomToRename: AgentWindowManager.ChatRoom? = nil
    
    @State private var inputText: String = ""
    @State private var pendingAttachments: [ChatAttachment] = []
    @State private var isTargetedForDrop: Bool = false
    @State private var scheduleDraftTime: String = "09:00"
    @State private var scheduleDraftPrompt: String = ""
    @State private var scheduleDraftAgentID: String = "auto"
    @State private var scheduleDraftError: String? = nil
    @State private var isFileIntakeSheetPresented: Bool = false
    @State private var collaborationStatusTick: Int = 0
    @State private var collaborationStatusRefreshTask: Task<Void, Never>? = nil
    @State private var latestEventType: AgentEventType? = nil
    @State private var latestEventTimestamp: Date? = nil
    @State private var latestToolName: String? = nil
    @State private var currentWorkflowStatus: WorkflowStatus? = nil
    
    private var bgColor: Color {
        manager.isDarkMode ? Color.black.opacity(isCollapsed ? 0.4 : 0.8) : Color.white.opacity(isCollapsed ? 0.3 : 0.75)
    }
    private var textColor: Color {
        manager.isDarkMode ? .white : .black
    }

    private var panelWidth: CGFloat {
        isCollapsed ? 300 : (selectedTab == 0 ? 300 : 600)
    }

    private var panelHeight: CGFloat {
        isCollapsed ? 40 : 480
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
            activeAgentNames: manager.activeAgents.map(\.name)
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
                    Text(selectedTab == 0 ? "팀 협업 중" : "팀 채팅방")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor.opacity(0.8))
                }
                
                Spacer()
                
                HStack(spacing: 14) {
                    // ⏰ 스케줄 버튼 (헤더 상단 접근)
                    Button(action: {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                            manager.isSchedulePanelPresented.toggle()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 11, weight: .semibold))
                            if !manager.automationTasks.isEmpty {
                                Text("\(manager.automationTasks.count)")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .foregroundColor(manager.isSchedulePanelPresented ? .orange : (manager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.6)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("스케줄 업무")

                    // 탭 전환 버튼
                    Button(action: { selectedTab = (selectedTab == 0 ? 1 : 0) }) {
                        Image(systemName: selectedTab == 0 ? "bubble.left.and.bubble.right.fill" : "person.3.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: isCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { manager.hideStatusWindow() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .foregroundColor(manager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isCollapsed.toggle()
                }
            }
            
            if !isCollapsed {
                Divider().background(textColor.opacity(0.05))

                if selectedTab == 0 {
                    // ── 탭 0: 에이전트 리스트 ──
                    agentListView
                } else {
                    // ── 탭 1: 팀 채팅방 (로그) ──
                    chatroomView
                }

                Divider().background(textColor.opacity(0.05))
            }
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
        .onChange(of: selectedTab) { _, newValue in
            if !isCollapsed {
                manager.updateStatusWindowSize(width: newValue == 0 ? 300 : 600, height: panelHeight)
            }
        }
        .onChange(of: isCollapsed) { _, _ in
            manager.updateStatusWindowSize(width: panelWidth, height: panelHeight)
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
        .overlay(alignment: .topTrailing) {
            if manager.isSchedulePanelPresented {
                GeometryReader { proxy in
                    let popupWidth = min(260, max(220, proxy.size.width - 22))
                    let popupHeight = min(220, max(160, proxy.size.height - 70))

                    schedulePopupCard
                        .frame(width: popupWidth, height: popupHeight, alignment: .topLeading)
                        .padding(.trailing, 10)
                        .padding(.top, 48)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isCollapsed {
                footerView
                    .padding(.top, 2)
            }
        }
        .sheet(isPresented: $isFileIntakeSheetPresented) {
            FileIntakeView { result in
                handleFileIntakeResult(result)
            }
        }
        .shadow(color: Color.black.opacity(manager.isDarkMode ? 0.3 : 0.08), radius: 15, x: 0, y: 8)
        .padding(10)
        .onAppear {
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
    }
    
    // MARK: - 하위 뷰 (에이전트 리스트)
    private var collaborationStatusBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(collaborationStatus.accentColor.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: collaborationStatus.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(collaborationStatus.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(collaborationStatus.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.8))
                        .lineLimit(1)
                    if let agentName = collaborationStatus.agentName {
                        Text(agentName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(textColor.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                if !collaborationStatus.detail.isEmpty {
                    Text(collaborationStatus.detail)
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.48))
                        .lineLimit(1)
                }
            }

            Spacer()

            if collaborationStatus.kind == .completed {
                Text("최근")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.12)))
            } else if collaborationStatus.kind == .failed {
                Text("확인")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(collaborationStatus.accentColor.opacity(manager.isDarkMode ? 0.10 : 0.08))
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var agentListView: some View {
        VStack(spacing: 0) {
            collaborationStatusBanner
            
            Divider().background(textColor.opacity(0.05))
            
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(manager.activeAgents) { agent in
                        StatusAgentRow(agent: agent, isDarkMode: manager.isDarkMode)
                            .onTapGesture {
                                manager.showChat(for: agent)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
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
                            isSelected: manager.currentRoomID == room.id,
                            isDarkMode: manager.isDarkMode,
                            isDeleteMode: isDeleteMode,
                            onRename: {
                                roomToRename = room
                                newName = room.name
                                showRenameAlert = true
                            }
                        )
                        .onTapGesture {
                            if isDeleteMode {
                                roomToDelete = room
                            } else {
                                manager.currentRoomID = room.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
            }
            .alert("프로젝트 이름 변경", isPresented: $showRenameAlert) {
                TextField("새 이름", text: $newName)
                Button("변경") {
                    if let r = roomToRename {
                        manager.renameRoom(id: r.id, newName: newName)
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("새 프로젝트 이름을 입력하세요.")
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
            Text("채팅방")
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
                manager.createRoom(name: "프로젝트 \(manager.rooms.count + 1)")
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("채팅방 추가")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var scheduleSidebarButton: some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                manager.isSchedulePanelPresented.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(manager.isSchedulePanelPresented ? .orange : textColor.opacity(0.5))
                    if !manager.automationTasks.isEmpty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -3)
                    }
                }
                Text("스케줄")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textColor.opacity(manager.isSchedulePanelPresented ? 0.78 : 0.48))
                Spacer()
                if !manager.automationTasks.isEmpty {
                    Text("\(manager.automationTasks.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(manager.isSchedulePanelPresented ? Color.orange.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .help("스케줄 업무")
    }

    private var chatroomLogView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if manager.teamChatLogs.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 28))
                                    .foregroundColor(textColor.opacity(0.2))
                                Text("아직 대화 내용이 없습니다.")
                                    .font(.system(size: 11))
                                    .foregroundColor(textColor.opacity(0.3))
                            }
                            .frame(maxWidth: .infinity).padding(.top, 30)
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
                                    if log.skillID != nil {
                                        SkillResultRendererView(
                                            skillID: log.skillID,
                                            text: log.text,
                                            isDarkMode: manager.isDarkMode,
                                            isUser: log.isUser
                                        )
                                    } else {
                                        if log.isUser {
                                            Text(log.text)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10).padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.blue)
                                                )
                                        } else {
                                            MarkdownTextView(
                                                text: log.text,
                                                isDarkMode: manager.isDarkMode
                                            )
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(manager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
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
                    }
                    .padding(12)
                }
                .background(Color.clear)
                .onChange(of: manager.teamChatLogs.count) { _, _ in
                    if let last = manager.teamChatLogs.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // ── Artifact 카드 (workflow 완료 후 생성 파일 빠른 열기) ──
            if !manager.recentArtifacts.isEmpty {
                Divider().background(textColor.opacity(0.06))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(manager.recentArtifacts, id: \.id) { artifact in
                            ArtifactCardView(artifact: artifact)
                                .frame(width: 240)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                }
                .frame(maxHeight: 110)
            }

            // ── 하단: 입력창 (팀 채팅 + 첨부파일) ──
            Divider().background(textColor.opacity(0.08))

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

            HStack(spacing: 8) {
                Button(action: openTeamFilePicker) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())

                TextField("팀원들에게 메시지...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isTargetedForDrop ? Color.blue.opacity(0.1) : textColor.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isTargetedForDrop ? Color.blue : Color.clear, lineWidth: 1))
                    )
                    .onSubmit { sendTeamMessage() }

                // ── 중지 버튼 (workflow 실행 중일 때만 표시) ──
                if manager.isWorkflowRunning {
                    Button(action: {
                        guard let roomID = manager.currentRoomID else { return }
                        WorkflowOrchestrator.shared.cancelCurrentWorkflow(roomID: roomID, manager: manager)
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("작업 중지")
                } else {
                    Button(action: sendTeamMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor((inputText.isEmpty && pendingAttachments.isEmpty) ? .gray.opacity(0.4) : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(inputText.isEmpty && pendingAttachments.isEmpty)
                }
            }
            .padding(10)
            .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url = url else { return }
                        Task { @MainActor in
                            if let a = await loadTeamAttachment(from: url) { pendingAttachments.append(a) }
                        }
                    }
                }
                return true
            }
        }
    }

    private var scheduleTasksPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
                Text("스케줄 업무")
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
                    Text("등록된 스케줄 업무가 없습니다.")
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

    private var schedulePopupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text("스케줄 근무")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(textColor.opacity(0.8))
                Spacer()
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

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if manager.automationTasks.isEmpty {
                        Text("등록된 근무가 없습니다.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.78))
                        Text("정해진 시간에 자동으로 작업하는 기능이 준비 중입니다.")
                            .font(.system(size: 10))
                            .foregroundColor(textColor.opacity(0.55))
                    } else {
                        Text("\(manager.automationTasks.count)개의 스케줄이 있습니다.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.78))

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(manager.automationTasks.prefix(3))) { task in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                    Text(task.prompt)
                                        .font(.system(size: 10))
                                        .foregroundColor(textColor.opacity(0.7))
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.trailing, 2)
            }
            .frame(maxHeight: 126)

            Button("스케줄 관리 준비 중") { }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(manager.isDarkMode ? Color.black.opacity(0.92) : Color.white.opacity(0.98))
                .shadow(color: .black.opacity(manager.isDarkMode ? 0.22 : 0.12), radius: 12, x: 0, y: 5)
        )
    }

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
                Text(scheduleDraftError)
                    .font(.system(size: 9))
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
        return "\(task.scheduleText) · \(agent.name)\(status)"
    }

    private func scheduleAgentMenuLabel(for agent: AgentWindowManager.AgentConfig) -> String {
        manager.activeAgents.contains(where: { $0.id == agent.id })
            ? agent.name
            : "\(agent.name) 없음"
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

        let assignedID = scheduleDraftAgentID == "auto" ? nil : scheduleDraftAgentID
        manager.addAutomationTask(
            prompt: prompt,
            nextRunAt: nextRunAt,
            roomID: manager.currentRoomID,
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
        let roomID = await MainActor.run { manager.currentRoomID }
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
        panel.begin { response in
            guard response == .OK else { return }
            Task {
                for url in panel.urls {
                    if let a = await loadTeamAttachment(from: url) {
                        await MainActor.run { pendingAttachments.append(a) }
                    }
                }
            }
        }
    }

    private func loadTeamAttachment(from url: URL) async -> ChatAttachment? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        let fileName = url.lastPathComponent
        let type = ChatAttachment.AttachmentType.from(fileName: fileName)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let textContent = FileContentExtractor.extractText(from: url)
        return ChatAttachment(fileName: fileName, fileSize: fileSize, type: type, textContent: textContent, localPath: url.path)
    }

    private func sendTeamMessage() {
        guard !inputText.isEmpty || !pendingAttachments.isEmpty else { return }
        // roomID를 Task 진입 전에 캡처 — 비동기 중 방 전환으로 인한 오염 차단
        guard let roomIDAtSend = manager.currentRoomID else { return }

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

            await MainActor.run {
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

        var body: some View {
            HStack(spacing: 6) {
                // 삭제 모드: 빨간 원 아이콘 / 일반: 말풍선
                if isDeleteMode {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "bubble.left.fill")
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
        }
    }

    // MARK: - 하위 뷰 (푸터 토글 및 버튼)
    private var footerView: some View {
        HStack(spacing: 12) {
            // 소리 테마 (음성/무음)
            HStack(spacing: 8) {
                Button(action: { manager.isSilentMode.toggle() }) {
                    Image(systemName: manager.isSilentMode ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(manager.isSilentMode ? .red.opacity(0.6) : .gray.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .help(manager.isSilentMode ? "무음 모드 켬" : "무음 모드 꿈")
                
                Button(action: { manager.isVoiceMode.toggle() }) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundColor(manager.isVoiceMode ? .blue : .gray.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())
                .help(manager.isVoiceMode ? "음성 모드 활성" : "음성 모드 비활성")
            }
            
            Spacer()
            
            // 다크모드 토글
            Button(action: { withAnimation { manager.isDarkMode.toggle() } }) {
                Image(systemName: manager.isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundColor(manager.isDarkMode ? .yellow : .orange.opacity(0.8))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { isFileIntakeSheetPresented = true }) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 12))
                    .foregroundColor(.blue.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
            .help("파일 읽기")
            
            // 위치 초기화 버튼 (추가)
            Button(action: { manager.resetWindowPositions() }) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 11))
                    .foregroundColor(.blue.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .help("윈도우 위치 초기화 (중앙으로)")
            
            Button(action: { manager.showSettingsWindow() }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func handleFileIntakeResult(_ result: FileIntakeResult) {
        guard let roomID = manager.currentRoomID ?? manager.rooms.first?.id else { return }

        manager.recordFileIntakeResult(result, roomID: roomID)

        let message: String
        switch result.status {
        case .ready:
            message = """
            파일을 읽었습니다.
            파일: \(result.request.originalFilename)
            다음 단계에서 요약/보고서/체크리스트로 만들 수 있습니다.
            """
        case .planned:
            message = """
            이 파일 형식은 아직 준비 중입니다.
            먼저 txt, md, csv 파일을 지원합니다.
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
                Text(agent.name).font(.system(size: 13, weight: .semibold)).foregroundColor(isDarkMode ? .white : .black)
                Text(agent.status).font(.system(size: 10)).foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isDarkMode ? .white.opacity(0.2) : .gray.opacity(0.3))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.02))
        )
    }
}
