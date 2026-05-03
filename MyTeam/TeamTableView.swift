import SwiftUI
import AppKit

// MARK: - TeamTableView
// 4명의 에이전트가 투명 창에 나란히 떠있는 메인 뷰.
struct TeamTableView: View {
    @EnvironmentObject var manager: AgentWindowManager
    @State private var isDragging = false
    @StateObject private var speechManager = SpeechManager.shared
    @State private var inputText: String = ""
    @State private var preRecordText: String = ""
    @State private var selectedAgentIndex: Int? = nil

    @AppStorage("teamName") private var teamName: String = "MyTeam"
    @AppStorage("showTeamName") private var showTeamName: Bool = true
    @AppStorage("teamNameColor") private var teamNameColor: String = "#FFFFFF"
    @AppStorage("agentWindowOpacity") private var agentWindowOpacity: Double = 0.0

    // 드래그 스팸 방지: 한 번의 드래그 제스처 당 알림 1회만 발생
    @State private var isBadgeDragActive: Bool = false
    // 드래그 TTS 중복 방지: agentDragBegan/Ended 알림이 여러 번 와도 speak()는 1회만
    @State private var hasSpokenOnDragBegan: Bool = false
    @State private var hasSpokenOnDragEnded: Bool = false

    private var plaqueBaseColor: Color {
        Color(hex: teamNameColor) ?? .white
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── 팀 명칭 배지 (클릭 시 도래깃 이동) ──
            if showTeamName && !teamName.isEmpty {
                Text(teamName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(plaqueBaseColor.isDark ? .white : .black.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(plaqueBaseColor.opacity(0.12))
                            .overlay(Capsule().stroke(plaqueBaseColor.opacity(0.18), lineWidth: 1))
                    )
                    .padding(.bottom, 6)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if let event = NSApplication.shared.currentEvent {
                                // 드래그 시작 시 1회만 알림 발송 (mouseDragged마다 발송 금지)
                                if !isBadgeDragActive {
                                    isBadgeDragActive = true
                                    NotificationCenter.default.post(name: .agentDragBegan, object: nil)
                                }
                                AgentWindowManager.shared.teamPanelWindow?.performDrag(with: event)
                            }
                        }
                        .onEnded { _ in
                            isBadgeDragActive = false
                            NotificationCenter.default.post(name: .agentDragEnded, object: nil)
                        }
                    )
            }

            // ── 에이전트 목록 ──
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(manager.activeAgents.enumerated()), id: \.element.id) { index, agent in
                    AgentSeatView(
                        config: agent,
                        isDragging: isDragging,
                        isSpeaking: manager.speakingAgentID == agent.id,
                        isThinking: false,
                        speechText: manager.speakingAgentID == agent.id
                            ? manager.rooms.flatMap { $0.messages }.last(where: { $0.agentID == agent.id && !$0.isUser })?.text
                            : nil,
                        isSelected: selectedAgentIndex == index,
                        onTap: {
                            selectedAgentIndex = (selectedAgentIndex == index) ? nil : index
                        }
                    )
                    .overlay(alignment: .topTrailing) {
                        if manager.teamLeader()?.id == agent.id {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.yellow)
                                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                                .offset(x: 8, y: -8)
                        }
                    }
                    .overlay(
                        AgentMenuPopupView(
                            isShowing: selectedAgentIndex == index,
                            popupOnLeft: index >= 3, // 4번째(index 3) 에이전트는 왼쪽에 표시
                            isTeamLeader: manager.teamLeader()?.id == agent.id,
                            onChat: {
                                selectedAgentIndex = nil
                                manager.showChat(for: agent)
                            },
                            onSettings: {
                                selectedAgentIndex = nil
                                manager.showAgentSettingsWindow(for: agent)
                            },
                            onSwap: {
                                selectedAgentIndex = nil
                                manager.showSwapWindow(replaceIndex: index)
                            },
                            onSetLeader: {
                                selectedAgentIndex = nil
                                if manager.teamLeader()?.id == agent.id {
                                    // 팀장 해제: 첫 번째 다른 에이전트로 교체
                                    if let other = manager.activeAgents.first(where: { $0.id != agent.id }) {
                                        manager.setTeamLeader(agentID: other.id)
                                    }
                                } else {
                                    manager.setTeamLeader(agentID: agent.id)
                                }
                            }
                        )
                        // 1~3번째는 캐릭터의 오른쪽 바깥에, 4번째는 왼쪽 바깥으로 완전히 빠져나오게 배치
                        .offset(x: index >= 3 ? -100 : 100, y: -80)
                        .zIndex(selectedAgentIndex == index ? 10 : 1),
                        alignment: index >= 3 ? .bottomTrailing : .bottomLeading
                    )
                    .zIndex(selectedAgentIndex == index ? 10 : 1)
                }
            }
            .zIndex(5)

            Spacer().frame(height: 20)

            // ── 하단 입력창 및 메뉴 ──
            HStack {
                Button(action: {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                    } else {
                        speechManager.requestAuthorization { authorized in
                            if authorized {
                                preRecordText = inputText
                                speechManager.startRecording()
                            }
                        }
                    }
                }) {
                    Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.fill")
                        .foregroundColor(speechManager.isRecording ? .red : .gray)
                }
                .buttonStyle(PlainButtonStyle())

                TextField("팀원들에게 인사해 보세요", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit { sendTeamInput() }

                Button("전송") { sendTeamInput() }
                .disabled(inputText.isEmpty)
                
                Menu {
                    Button(action: { manager.showStatusWindow() }) {
                        Label("협업창 보기", systemImage: "person.3.fill")
                    }
                    Button(action: { manager.showSwapWindow() }) {
                        Label("팀원 교체하기", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Menu {
                        ForEach(manager.activeAgents) { agent in
                            Button(action: { manager.setTeamLeader(agentID: agent.id) }) {
                                Label(agent.name, systemImage: manager.teamLeader()?.id == agent.id ? "crown.fill" : "person.fill")
                            }
                        }
                    } label: {
                        Label("팀 리더 지정", systemImage: "crown.fill")
                    }
                    Button(action: { manager.showSettingsWindow() }) {
                        Label("설정하기", systemImage: "gearshape.fill")
                    }
                    Divider()
                    Button(action: {
                        let agent = manager.activeAgents.randomElement() ?? manager.activeAgents[0]
                        let text = "오늘 너무 고생하셨습니다. 앱을 곧 종료할게요!"
                        manager.addChatLog(agentID: agent.id, agentName: agent.name, text: text, isUser: false, isSystem: true)
                        if !manager.isSilentMode { SpeechManager.shared.speak(text: text) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            NSApplication.shared.terminate(nil)
                        }
                    }) {
                        Label("어플리케이션 종료", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray.opacity(0.8))
                        .contentShape(Rectangle())
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 24, height: 24)
                .help("메뉴 열기 (드래그하여 이동 가능)")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .zIndex(1)
        }
        .padding(.horizontal, 16)
        .background(Color.black.opacity(agentWindowOpacity > 0.99 ? 0.0 : (1.0 - agentWindowOpacity) * 0.6)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .frame(width: 460, height: 280)
        .onReceive(NotificationCenter.default.publisher(for: .agentDragBegan)) { _ in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                isDragging = true
                selectedAgentIndex = nil
            }
            // 중복 방지: 이미 말한 경우 skip (알림이 여러 번 와도 speak()는 1회만)
            guard !hasSpokenOnDragBegan else { return }
            hasSpokenOnDragBegan = true

            // 드래그 시작 시 랜덤 에이전트 1명만 말함
            if let agent = manager.activeAgents.randomElement() {
                let fallback = ["어?! 잠깐만요!", "으아아!", "헉!"]
                let line = CharacterDialogues.randomLine(for: agent.name, state: .drag) ?? fallback.randomElement()!
                manager.addChatLog(agentID: agent.id, agentName: agent.name, text: line, isUser: false, isSystem: true)
                if !manager.isSilentMode {
                    manager.setAgentSpeaking(agentID: agent.id, text: line)
                    SpeechManager.shared.speak(text: line, agentID: agent.id, characterName: agent.name)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentDragEnded)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isDragging = false
            }
            // 드래그 종료: 플래그 초기화 + 착지 대사 1회 (중복 방지)
            hasSpokenOnDragBegan = false
            guard !hasSpokenOnDragEnded else {
                // 타이머로 플래그 초기화 (다음 드래그를 위해)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    hasSpokenOnDragEnded = false
                }
                return
            }
            hasSpokenOnDragEnded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hasSpokenOnDragEnded = false
            }

            if let agent = manager.activeAgents.randomElement() {
                let fallback = ["휴, 다시 돌아왔네요.", "무사히 착지!"]
                let line = CharacterDialogues.randomLine(for: agent.name, state: .landing) ?? fallback.randomElement()!
                manager.addChatLog(agentID: agent.id, agentName: agent.name, text: line, isUser: false, isSystem: true)
                if !manager.isSilentMode {
                    manager.setAgentSpeaking(agentID: agent.id, text: line)
                    SpeechManager.shared.speak(text: line, agentID: agent.id, characterName: agent.name)
                }
            }
        }
        .onChange(of: speechManager.recognizedText) { _, newText in
            if speechManager.isRecording {
                let prefix = preRecordText.isEmpty ? "" : preRecordText + " "
                inputText = prefix + newText
            }
        }
    }

    // MARK: - 팀 입력 전송 (AIService 직접 호출)
    private func sendTeamInput() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""

        Task {
            if await ConversationMemory.handleChatCommand(
                text,
                roomID: manager.currentRoomID,
                manager: manager,
                currentAgent: manager.fallbackTeamLeader()
            ) {
                return
            }
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") else { return }

        manager.addChatLog(agentID: "user", agentName: "나", text: text, isUser: true)

        Task {
            guard let roomID = manager.currentRoomID else { return }
            await TeamOrchestrator.shared.runTeamDiscussion(
                userMessage: text,
                roomID: roomID,
                manager: manager
            )
        }
    }
}

// AgentMenuPopupView → AgentMenuPopupView.swift 로 분리됨
// AgentSeatView → AgentSeatView.swift 로 분리됨
