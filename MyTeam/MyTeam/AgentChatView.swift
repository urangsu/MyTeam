import SwiftUI
import AppKit

// MARK: - AgentChatView
// iMessage 스타일 개별 채팅창 (팀 채팅과 동일한 레이아웃)
struct AgentChatView: View {
    let config: AgentWindowManager.AgentConfig
    let onClose: () -> Void

    @EnvironmentObject var manager: AgentWindowManager
    @StateObject private var wsClient = WebSocketClient.shared
    @StateObject private var speechManager = SpeechManager.shared
    @State private var inputText: String = ""
    @State private var initialGreeting: String = "안녕하세요! 어떤 프로젝트부터 도와드릴까요?"
    @State private var preRecordText: String = ""
    @State private var selectedTab: Int = 1 // 기본 1: 채팅 모드 (확장 상태)

    // 현재 선택된 에이전트 (사이드바 전환용)
    @State private var activeAgentID: String? = nil

    // 1:1 또는 팀 채팅 구분 플래그
    var isPersonalChat: Bool = true

    // 현재 방의 채팅 내역 필터링
    private var chatHistory: [AgentWindowManager.ChatLog] {
        let logs = manager.rooms.first(where: { $0.id == manager.currentRoomID })?.messages ?? []
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

    // 다크모드 대응 색상
    private var bgColor: Color {
        manager.isDarkMode ? Color(red: 0.09, green: 0.09, blue: 0.11) : Color(red: 0.97, green: 0.97, blue: 0.99)
    }
    private var textColor: Color { manager.isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12) }
    private var subTextColor: Color { manager.isDarkMode ? .white.opacity(0.45) : .black.opacity(0.35) }
    private var dividerColor: Color { manager.isDarkMode ? .white.opacity(0.07) : .black.opacity(0.06) }
    private var inputBgColor: Color { manager.isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04) }

    var body: some View {
        HStack(spacing: 0) {
            // ── 사이드바 ──
            sidebarView

            Divider().background(dividerColor)

            // ── 메인 영역 ──
            VStack(spacing: 0) {
                // ── 1. 헤더 ──
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(currentAgent.color.opacity(manager.isDarkMode ? 0.3 : 0.15))
                            .frame(width: 40, height: 40)
                        Text(currentAgent.emoji)
                            .font(.system(size: 24))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentAgent.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textColor)
                        
                        if selectedTab == 1 {
                             if let room = manager.rooms.first(where: { $0.id == manager.currentRoomID }) {
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
                        // 탭 전환 버튼
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = (selectedTab == 0 ? 1 : 0)
                            }
                        }) {
                            Image(systemName: selectedTab == 0 ? "bubble.left.and.bubble.right.fill" : "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(subTextColor)
                        }

                        // 음성/마이크 버튼
                        if selectedTab == 1 {
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

                        // 닫기
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(subTextColor)
                                .font(.system(size: 18))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(bgColor)

                Divider().background(dividerColor)

                if selectedTab == 1 {
                    // ── 2-1. 채팅 로그 (확장 모드) ──
                    chatLogView
                } else {
                    // ── 2-2. 에이전트 프로필/상태 (압축 모드) ──
                    agentStatusView
                }
            }
        }
        .onAppear {
            let greetings = [
                "안녕하세요! 어떤 프로젝트부터 도와드릴까요?",
                "반갑습니다. 오늘 하루도 파이팅해 볼까요?",
                "무엇을 도와드릴까요? 편하게 말씀해 주세요.",
                "준비 완료! 어떤 작업을 시작할까요?",
                "안녕하세요. 오늘은 어떤 일로 오셨나요?"
            ]
            self.initialGreeting = greetings.randomElement() ?? greetings[0]
            self.activeAgentID = config.id
        }
        .frame(width: selectedTab == 0 ? 300 : 600, height: 600)
        .onChange(of: selectedTab) { _, newValue in
            manager.updateChatWindowWidth(id: config.id, width: newValue == 0 ? 300 : 600)
        }
    }

    // MARK: - 하위 뷰 (채팅 로그)
    private var chatLogView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        IMMessageBubble(
                            text: initialGreeting,
                            isUser: false,
                            agentName: currentAgent.name,
                            agentEmoji: currentAgent.emoji,
                            agentColor: currentAgent.color,
                            isDarkMode: manager.isDarkMode,
                            timestamp: nil
                        )
                        .padding(.top, 12)

                        ForEach(Array(chatHistory.enumerated()), id: \.element.id) { index, log in
                            if index == 0 || !Calendar.current.isDate(
                                log.timestamp, inSameDayAs: chatHistory[index - 1].timestamp
                            ) {
                                DateSeparator(date: log.timestamp)
                            }

                            IMMessageBubble(
                                text: log.text,
                                isUser: log.isUser,
                                agentName: log.isUser ? "나" : log.agentName,
                                agentEmoji: log.isUser ? "👤" : currentAgent.emoji,
                                agentColor: log.isUser ? .blue : currentAgent.color,
                                isDarkMode: manager.isDarkMode,
                                timestamp: log.timestamp
                            )
                            .id(log.id)
                        }

                        if wsClient.currentSpeakerID == (activeAgentID ?? config.id) {
                            if wsClient.agentStatus == "Thinking" {
                                thinkingBubble
                            } else if !wsClient.currentMessage.isEmpty {
                                IMMessageBubble(
                                    text: wsClient.currentMessage,
                                    isUser: false,
                                    agentName: currentAgent.name,
                                    agentEmoji: currentAgent.emoji,
                                    agentColor: currentAgent.color,
                                    isDarkMode: manager.isDarkMode,
                                    timestamp: nil
                                )
                                .id("current_speaking")
                            }
                        }

                        Color.clear.frame(height: 8).id("bottom_anchor")
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .onChange(of: chatHistory.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                }
                .onChange(of: wsClient.currentMessage) { _, _ in
                    proxy.scrollTo("current_speaking", anchor: .bottom)
                }
                .onChange(of: wsClient.agentStatus) { _, newValue in
                    if newValue == "Thinking" {
                        proxy.scrollTo("thinking_spinner", anchor: .bottom)
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

            // 입력창
            inputFieldView
        }
    }

    private var thinkingBubble: some View {
        HStack(spacing: 6) {
            Circle().fill(currentAgent.color.opacity(0.5)).frame(width: 6, height: 6)
            Circle().fill(currentAgent.color.opacity(0.35)).frame(width: 5, height: 5)
            Circle().fill(currentAgent.color.opacity(0.2)).frame(width: 4, height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18).fill(manager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06)))
        .padding(.leading, 54).padding(.vertical, 2)
        .id("thinking_spinner")
    }

    private var inputFieldView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                TextField("\(currentAgent.name)에게 메시지...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(textColor)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 20).fill(inputBgColor))
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(inputText.isEmpty ? subTextColor : currentAgent.color)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(inputText.isEmpty)
            }
            if let errorMsg = speechManager.sttError {
                Text(errorMsg).font(.system(size: 10)).foregroundColor(.red)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).background(bgColor)
    }

    // MARK: - 하위 뷰 (프로필/상태)
    private var agentStatusView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(currentAgent.emoji)
                .font(.system(size: 64))
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

    // MARK: - 하위 뷰 (사이드바)
    private var sidebarView: some View {
        VStack(spacing: 0) {
            Text("멤버")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(textColor.opacity(0.4))
                .padding(.vertical, 10)
            Divider().background(dividerColor)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(manager.activeAgents) { agent in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(agent.color.opacity(activeAgentID == agent.id ? 0.2 : 0.05)).frame(width: 44, height: 44)
                                Text(agent.emoji).font(.system(size: 22))
                            }
                            Text(agent.name.prefix(2)).font(.system(size: 10, weight: .medium)).foregroundColor(activeAgentID == agent.id ? .blue : textColor.opacity(0.5))
                        }
                        .onTapGesture { withAnimation { activeAgentID = agent.id } }
                    }
                }
                .padding(.vertical, 14)
            }
        }
        .frame(width: 85)
        .background(manager.isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.025))
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        wsClient.sendMessage(inputText, targetAgentID: activeAgentID ?? config.id)
        inputText = ""
    }
}

// MARK: - iMessage 스타일 말풍선 & DateSeparator (생략 - 기존과 동일)
struct IMMessageBubble: View {
    let text: String; let isUser: Bool; let agentName: String; let agentEmoji: String; let agentColor: Color; let isDarkMode: Bool; let timestamp: Date?
    private var bubbleBg: Color { isUser ? .blue : (isDarkMode ? Color.white.opacity(0.11) : Color.black.opacity(0.07)) }
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser { Text(agentEmoji).font(.system(size: 22)).frame(width: 34) } else { Spacer() }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if !isUser { Text(agentName).font(.system(size: 10, weight: .semibold)).foregroundColor(agentColor.opacity(0.85)) }
                Text(text).font(.system(size: 14)).foregroundColor(isUser ? .white : (isDarkMode ? .white : .black)).padding(.horizontal, 14).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18).fill(bubbleBg)).frame(maxWidth: 260, alignment: isUser ? .trailing : .leading)
                if let ts = timestamp { Text(ts, style: .time).font(.system(size: 9)).foregroundColor(.gray.opacity(0.5)) }
            }
            if isUser { Spacer().frame(width: 8) }
        }.padding(.vertical, 2)
    }
}
struct DateSeparator: View {
    let date: Date
    var body: some View {
        HStack { Spacer(); Text(date, style: .date).font(.system(size: 10, weight: .bold)).foregroundColor(.gray.opacity(0.6)).padding(.horizontal, 12).padding(.vertical, 4).background(Capsule().fill(Color.gray.opacity(0.1))); Spacer() }.padding(.vertical, 8)
    }
}
struct ChatBubble: View {
    let message: String; let isUser: Bool; let emoji: String; let isDarkMode: Bool; let accentColor: Color
    var body: some View { IMMessageBubble(text: message, isUser: isUser, agentName: "", agentEmoji: emoji, agentColor: accentColor, isDarkMode: isDarkMode, timestamp: nil) }
}
