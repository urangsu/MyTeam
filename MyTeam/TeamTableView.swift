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
                                NotificationCenter.default.post(name: .agentDragBegan, object: nil)
                                AgentWindowManager.shared.teamPanelWindow?.performDrag(with: event)
                            }
                        }
                        .onEnded { _ in
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
                        isSpeaking: false,
                        isThinking: false,
                        speechText: nil,
                        isSelected: selectedAgentIndex == index,
                        onTap: {
                            selectedAgentIndex = (selectedAgentIndex == index) ? nil : index
                        }
                    )
                    .overlay(
                        AgentMenuPopupView(
                            isShowing: selectedAgentIndex == index,
                            popupOnLeft: index >= 3, // 4번째(index 3) 에이전트는 왼쪽에 표시
                            onChat: {
                                selectedAgentIndex = nil
                                manager.showChat(for: agent)
                            },
                            onVoice: {
                                selectedAgentIndex = nil
                                let fallback = ["안녕하세요!", "네, 불렀나요?", "무엇을 도와드릴까요?", "여기 있습니다!"]
                                let text = CharacterDialogues.randomLine(for: agent.name, state: .greeting) ?? fallback.randomElement()!
                                manager.addChatLog(agentID: agent.id, agentName: agent.name, text: text, isUser: false, isSystem: true)
                                if !manager.isSilentMode { SpeechManager.shared.speak(text: text, characterName: agent.name) }
                            },
                            onSettings: {
                                selectedAgentIndex = nil
                                manager.showAgentSettingsWindow(for: agent)
                            },
                            onSwap: {
                                selectedAgentIndex = nil
                                manager.showSwapWindow(replaceIndex: index)
                            }
                        )
                        // 1~3번째는 캐릭터의 오른쪽 바깥에, 4번째는 왼쪽 바깥으로 완전히 빠져나오게 배치
                        .offset(x: index >= 3 ? -100 : 100, y: -95)
                        .zIndex(selectedAgentIndex == index ? 10 : 1),
                        alignment: index >= 3 ? .topTrailing : .topLeading
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
                    Button(action: { manager.showSettingsWindow() }) {
                        Label("API 설정하기", systemImage: "gearshape.fill")
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
        .background(Color.clear)
        .frame(width: 460, height: 280)
        .onReceive(NotificationCenter.default.publisher(for: .agentDragBegan)) { _ in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                isDragging = true
                selectedAgentIndex = nil
            }
            // 드래그 시작 시 랜덤 에이전트의 캐릭터별 대사 출력
            if let agent = manager.activeAgents.randomElement() {
                let fallback = ["어?! 잠깐만요!", "으아아!", "헉!"]
                let line = CharacterDialogues.randomLine(for: agent.name, state: .drag) ?? fallback.randomElement()!
                manager.addChatLog(agentID: agent.id, agentName: agent.name, text: line, isUser: false, isSystem: true)
                if !manager.isSilentMode { SpeechManager.shared.speak(text: line, characterName: agent.name) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentDragEnded)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isDragging = false
            }
            // 착지 시 같은 맥락의 캐릭터별 대사 출력
            if let agent = manager.activeAgents.randomElement() {
                let fallback = ["휴, 다시 돌아왔네요.", "무사히 착지!"]
                let line = CharacterDialogues.randomLine(for: agent.name, state: .landing) ?? fallback.randomElement()!
                manager.addChatLog(agentID: agent.id, agentName: agent.name, text: line, isUser: false, isSystem: true)
                if !manager.isSilentMode { SpeechManager.shared.speak(text: line, characterName: agent.name) }
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

        let agents = manager.activeAgents
        let randomAgent = agents.randomElement() ?? agents[0]

        manager.addChatLog(agentID: "user", agentName: "나", text: text, isUser: true)

        Task {
            let history = manager.rooms.first(where: { $0.id == manager.currentRoomID })?
                .messages.map { "\($0.isUser ? "User" : $0.agentName): \($0.text)" } ?? []
            do {
                let (responseText, _) = try await AIService.shared.getResponse(
                    text: text, agentID: randomAgent.id, chatHistory: history
                )
                await MainActor.run {
                    manager.addChatLog(agentID: randomAgent.id, agentName: randomAgent.name, text: responseText, isUser: false)
                    if !manager.isSilentMode { SpeechManager.shared.speak(text: responseText, characterName: randomAgent.name) }
                }
            } catch {
                await MainActor.run {
                    manager.addChatLog(agentID: randomAgent.id, agentName: "시스템", text: error.localizedDescription, isUser: false)
                }
            }
        }
    }
}

// AgentMenuPopupView → AgentMenuPopupView.swift 로 분리됨
// AgentSeatView → AgentSeatView.swift 로 분리됨
