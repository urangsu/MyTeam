import SwiftUI
import AppKit

// MARK: - AgentChatView
// 고도화: 크기 확대, 다크모드 대응, 긴 텍스트 문단 분절 처리
struct AgentChatView: View {
    let config: AgentWindowManager.AgentConfig
    let onClose: () -> Void
    
    @EnvironmentObject var manager: AgentWindowManager
    @StateObject private var wsClient = WebSocketClient.shared
    @StateObject private var speechManager = SpeechManager.shared
    
    @State private var inputText: String = ""
    @State private var initialGreeting: String = "안녕하세요! 어떤 프로젝트부터 도와드릴까요?"
    
    // 녹음 시작 시 기존에 쓰던 텍스트를 보존하기 위한 변수
    @State private var preRecordText: String = ""
    
    // 이 대화방에 해당하는 1:1 채팅 내역 필터링
    private var chatHistory: [AgentWindowManager.ChatLog] {
        manager.teamChatLogs.filter { log in
            // 매니저에 저장된 로그 중, 이 에이전트가 발신했거나,
            // 사용자가 발신했는데 targetAgentID가 이 에이전트인 경우(하지만 현재 log에는 타겟 정보가 없음)
            // 임시로: 이 창에서 전송된 건 모두 targetAgentID가 config.id로 ws에 날아갔으나,
            // ChatLog 모델에 target을 넣지 않았으므로, 1:1 컨텍스트를 위해 단순 휴리스틱 적용:
            // 에이전트 발화이거나, 사용자의 최신 메시지들 위주로 보여줄 수 있지만,
            // 더 정확히는 TeamLog 전체 중 이 에이전트 이름이 포함되거나 사용자가 보낸 것을 필터링.
            // (완벽한 1:1 분리를 위해선 Log 모델 수정이 필요하지만 현재는 임시 연동)
            return log.agentID == config.id || (log.isUser)
        }
    }
    
    // 다크모드 대응 색상
    private var bgColor: Color {
        manager.isDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.85)
    }
    private var textColor: Color {
        manager.isDarkMode ? .white : .black
    }
    private var subTextColor: Color {
        manager.isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── 1. 상단 헤더 ──
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(config.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(config.emoji)
                        .font(.system(size: 28))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(config.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(textColor)
                    Text(config.role)
                        .font(.system(size: 12))
                        .foregroundColor(subTextColor)
                }
                
                Spacer()
                
                HStack(spacing: 18) {
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
                        Group {
                            if speechManager.isStarting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                    .scaleEffect(0.7)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic")
                                    .foregroundColor(speechManager.isRecording ? .red : subTextColor)
                            }
                        }
                    }
                    .disabled(speechManager.isStarting)
                    Button(action: { /* 공유 */ }) { Image(systemName: "square.and.arrow.up") }
                    Button(action: onClose) { Image(systemName: "xmark") }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(subTextColor)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider().background(textColor.opacity(0.05))
            
            // ── 2. 대화 내용 리스트 ──
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 기본 인사말 (랜덤)
                        ChatBubble(
                            message: initialGreeting,
                            isUser: false,
                            emoji: config.emoji,
                            isDarkMode: manager.isDarkMode,
                            accentColor: config.color
                        )
                        // 대화 기록 (필터링된 1:1 내역)
                        ForEach(chatHistory) { log in
                            ChatBubble(
                                message: log.text,
                                isUser: log.isUser,
                                emoji: log.isUser ? "👤" : config.emoji,
                                isDarkMode: manager.isDarkMode,
                                accentColor: log.isUser ? .blue : config.color
                            )
                            .id(log.id)
                        }
                        
                        // 실시간 메시지 (또는 로딩 스피너)
                        if wsClient.currentSpeakerID == config.id {
                            if wsClient.agentStatus == "Thinking" {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: subTextColor))
                                        .scaleEffect(0.6)
                                    Text("생각 중...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(subTextColor)
                                }
                                .padding(.top, 10)
                                .padding(.leading, 10)
                                .id("thinking_spinner")
                            } else if !wsClient.currentMessage.isEmpty {
                                ChatBubble(
                                    message: wsClient.currentMessage,
                                    isUser: false,
                                    emoji: config.emoji,
                                    isDarkMode: manager.isDarkMode,
                                    accentColor: config.color
                                )
                                .id("current_speaking")
                            }
                        }
                    }
                    .padding(24)
                    .onChange(of: chatHistory.count) {
                        withAnimation {
                            if let lastLog = chatHistory.last {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: wsClient.currentMessage) {
                        withAnimation {
                            proxy.scrollTo("current_speaking", anchor: .bottom)
                        }
                    }
                    .onChange(of: wsClient.agentStatus) { _, newValue in
                        if newValue == "Thinking" {
                            withAnimation {
                                proxy.scrollTo("thinking_spinner", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: speechManager.recognizedText) { _, newText in
                        // 녹음 중일 때 진행중인 텍스트 스트림을 보여줌
                        if speechManager.isRecording {
                            let prefix = preRecordText.isEmpty ? "" : preRecordText + " "
                            inputText = prefix + newText
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider().background(textColor.opacity(0.05))
            
            // ── 3. 하단 입력창 ──
            VStack(spacing: 12) {
                HStack {
                    TextField("\(config.name)에게 메시지...", text: $inputText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(textColor)
                        .font(.system(size: 14))
                        .onSubmit { sendMessage() }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(inputText.isEmpty ? subTextColor : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(manager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                )
                
                if let errorMsg = speechManager.sttError {
                    Text(errorMsg)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                
                Text(config.status)
                    .font(.system(size: 11))
                    .foregroundColor(subTextColor.opacity(0.7))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(bgColor)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(manager.isDarkMode ? Color.white.opacity(0.02) : Color.blue.opacity(0.02))
                    )
                RoundedRectangle(cornerRadius: 32)
                    .stroke(textColor.opacity(0.1), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(manager.isDarkMode ? 0.4 : 0.15), radius: 25, x: 0, y: 12)
        .onAppear {
            let greetings = [
                "안녕하세요! 어떤 프로젝트부터 도와드릴까요?",
                "반갑습니다. 오늘 하루도 파이팅해 볼까요?",
                "무엇을 도와드릴까요? 편하게 말씀해 주세요.",
                "준비 완료! 어떤 작업을 시작할까요?",
                "안녕하세요. 오늘은 어떤 일로 오셨나요?"
            ]
            self.initialGreeting = greetings.randomElement() ?? greetings[0]
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        // WebSocketClient에서 전역 로깅 및 전송 처리 (대상 에이전트를 명시)
        wsClient.sendMessage(inputText, targetAgentID: config.id)
        
        inputText = ""
    }
}

// 개별 채팅 말풍선 뷰 (문단 분절 지원)
struct ChatBubble: View {
    let message: String
    let isUser: Bool
    let emoji: String
    let isDarkMode: Bool
    let accentColor: Color
    
    // 긴 메시지를 3줄 정도 분량의 문단으로 나누는 로직 (간이 구현)
    var paragraphs: [String] {
        // 실제로는 글자 수나 개행 문자를 기준으로 나눌 수 있음
        // 여기서는 문장 부호(. ? !) 기준으로 합쳐서 적당히 분할
        let sentences = message.components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        var result: [String] = []
        var current: String = ""
        
        for (index, sentence) in sentences.enumerated() {
            current += sentence + (index < sentences.count ? "." : "")
            if (index + 1) % 2 == 0 { // 2문장마다 문단 나누기 (가독성 예시)
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        if !current.isEmpty { result.append(current.trimmingCharacters(in: .whitespaces)) }
        
        return result.isEmpty ? [message] : result
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !isUser {
                Text(emoji).font(.system(size: 24))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // 상단에 이름 표시 (색상 적용)
                Text(isUser ? "나" : (AgentWindowManager.shared.activeAgents.first(where: { $0.emoji == emoji })?.name ?? "에이전트"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isUser ? .blue : accentColor)
                    .padding(.bottom, 2)
                
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(4) // 줄 간격 추가
                        .foregroundColor(isUser ? .white : (isDarkMode ? .white : .black.opacity(0.85)))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isUser ? Color.blue : (isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06)))
                        )
                }
            }
            if isUser { Spacer() }
        }
    }
}
