import SwiftUI
import AppKit

// MARK: - TeamTableView
// 4명의 에이전트가 투명 창에 나란히 떠있는 메인 뷰.
struct TeamTableView: View {
    @EnvironmentObject var manager: AgentWindowManager
    @State private var isDragging = false
    @StateObject private var wsClient = WebSocketClient.shared
    @StateObject private var speechManager = SpeechManager.shared
    @State private var inputText: String = ""
    @State private var preRecordText: String = ""
    @State private var selectedAgentIndex: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── 에이전트 목록 ──
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(manager.activeAgents.enumerated()), id: \.element.id) { index, agent in
                    AgentSeatView(
                        config: agent,
                        isDragging: isDragging,
                        isSpeaking: wsClient.currentSpeakerID == agent.id,
                        isThinking: wsClient.currentSpeakerID == agent.id && wsClient.agentStatus == "Thinking",
                        speechText: wsClient.currentSpeakerID == agent.id ? wsClient.currentMessage : nil,
                        isSelected: selectedAgentIndex == index,
                        onTap: {
                            selectedAgentIndex = (selectedAgentIndex == index) ? nil : index
                        }
                    )
                    .overlay(
                        AgentMenuPopupView(
                            isShowing: selectedAgentIndex == index,
                            onChat: {
                                selectedAgentIndex = nil
                                manager.showChat(for: agent)
                            },
                            onVoice: {
                                selectedAgentIndex = nil
                                print("음성 통화 연결: \(agent.name)")
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
                        .offset(x: index == 3 ? -110 : 110, y: -40),
                        alignment: .center
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
                    .onSubmit {
                        if !inputText.isEmpty && wsClient.isConnected {
                            wsClient.sendMessage("[전회] " + inputText)
                            inputText = ""
                        }
                    }
                
                Button("전송") {
                    wsClient.sendMessage("[전회] " + inputText)
                    inputText = ""
                }
                .disabled(inputText.isEmpty || !wsClient.isConnected)
                
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
                        WebSocketClient.shared.sendSystemEvent(eventType: "shutdown", baseGreeting: "오늘 너무 고생하셨습니다. 앱을 곧 종료할게요!")
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentDragEnded)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { 
                isDragging = false 
            }
        }
        .onChange(of: speechManager.recognizedText) { _, newText in
            if speechManager.isRecording {
                let prefix = preRecordText.isEmpty ? "" : preRecordText + " "
                inputText = prefix + newText
            }
        }
    }
}

// MARK: - AgentMenuPopupView
struct AgentMenuPopupView: View {
    var isShowing: Bool
    var onChat: () -> Void
    var onVoice: () -> Void
    var onSettings: () -> Void
    var onSwap: () -> Void
    
    var body: some View {
        if isShowing {
            VStack(alignment: .leading, spacing: 0) {
                MenuButton(icon: "message", text: "채팅", action: onChat)
                MenuButton(icon: "mic", text: "음성", action: onVoice)
                Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 8)
                MenuButton(icon: "slider.horizontal.3", text: "추가 설정", action: onSettings)
                MenuButton(icon: "arrow.triangle.2.circlepath", text: "교체", action: onSwap)
            }
            .frame(width: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
            )
            .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
        }
    }
    
    struct MenuButton: View {
        let icon: String
        let text: String
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray)
                    Text(text).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - AgentSeatView
struct AgentSeatView: View {
    let config: AgentWindowManager.AgentConfig
    var isDragging: Bool
    var isSpeaking: Bool
    var isThinking: Bool
    var speechText: String?
    var isSelected: Bool
    var onTap: () -> Void
    
    @State private var lastClickTime: Date = .distantPast
    @State private var rapidClickCount: Int = 0

    @State private var isHovered = false

    // 사용자가 요청한 '3문장(또는 3줄) 단위 분절' 로직
    var speechParagraphs: [String] {
        guard let text = speechText, !text.isEmpty else { return [] }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        var result: [String] = []
        var current: String = ""
        for (index, sentence) in sentences.enumerated() {
            current += sentence + (index < sentences.count ? ". " : " ")
            // 3문장마다 끊어서 새로운 문단 생성
            if (index + 1) % 3 == 0 {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 4) {
            // 말풍선 (문단 분절 또는 로딩 스피너)
            if isThinking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .offset(y: -10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if isSpeaking, !speechParagraphs.isEmpty {
                VStack(spacing: 4) {
                    ForEach(speechParagraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .multilineTextAlignment(.center)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(config.color.opacity(0.85))
                            )
                    }
                }
                .offset(y: -10)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Color.clear.frame(height: 10)
            }

            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.pink, lineWidth: 2)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.pink.opacity(0.1)))
                        .frame(width: 80, height: 80)
                } else {
                    Color.clear.frame(width: 80, height: 80)
                }
                
                if isHovered && !isDragging {
                    VStack(spacing: 2) {
                        Text(config.name).font(.system(size: 11, weight: .bold))
                        Text(config.role).font(.system(size: 9))
                    }
                    .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(config.color.opacity(0.9)))
                    .offset(y: -40)
                    .transition(.opacity.combined(with: .scale))
                }
                
                Text(isDragging ? config.dragEmoji : config.emoji)
                    .font(.system(size: 50))
                    .rotationEffect(.degrees(isDragging ? config.dragRotation : 0))
                    .scaleEffect(isHovered && !isDragging ? 1.1 : 1.0)
            }

            HStack(spacing: 3) {
                Circle()
                    .fill(isSpeaking ? Color.yellow : Color.green)
                    .frame(width: 4, height: 4)
                    .shadow(color: isSpeaking ? .yellow : .green, radius: 2)
                Text(isSpeaking ? "말하는 중" : "대기 중")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 100)
        .contentShape(Rectangle())
        .onHover { h in isHovered = h }
        .onTapGesture {
            AgentWindowManager.shared.updateInteractionTime()
            let now = Date()
            if now.timeIntervalSince(lastClickTime) < 0.5 {
                rapidClickCount += 1
                if rapidClickCount >= 3 {
                    let rapidGreetings = ["앗, 간지러워요!", "살살요!", "정신이 하나도 없어요!", "게임 아니에요~"]
                    WebSocketClient.shared.sendSystemEvent(eventType: "rapid_click", baseGreeting: rapidGreetings.randomElement()!)
                    rapidClickCount = 0
                }
                } else {
                rapidClickCount = 1
                let clickGreetings = ["네, 저 여기 있어요!", "말씀하세요!", "무슨 일이죠?", "넵! 대기 중!"]
                WebSocketClient.shared.sendSystemEvent(eventType: "click", baseGreeting: clickGreetings.randomElement()!, agentID: config.id)
            }
            lastClickTime = now
            onTap()
        }
    }
}
