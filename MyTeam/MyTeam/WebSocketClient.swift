import Foundation
import Combine

// MARK: - WebSocketMessage
// 백엔드와 주고받을 메시지 구조체
struct WSAgentResponse: Codable {
    let type: String
    let agent_id: String
    let text: String
    let status: String
    let audio_base64: String?
    let is_system: Bool?
}

// MARK: - WebSocketClient
// Python 백엔드 (ws://localhost:8000/ws) 와 통신합니다.
class WebSocketClient: ObservableObject {
    
    static let shared = WebSocketClient()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let url = URL(string: "ws://127.0.0.1:8000/ws")!
    
    // UI 업데이트용 속성들 (@Published)
    @Published var isConnected = false
    @Published var currentSpeakerID: String? = nil
    @Published var currentMessage: String = ""
    @Published var agentStatus: String = "Idle"
    
    private var messageQueue: [URLSessionWebSocketTask.Message] = []
    
    private init() {
        connect()
    }
    
    func connect() {
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // 연결 상태는 receiveMessage에서 첫 성공 시 또는 별도 대기 로직으로 전환 가능하나,
        // 여기서는 일단 true로 두고 실패 시 처리하도록 유지하되 flushQueue를 연동합니다.
        isConnected = true
        receiveMessage()
        print("WebSocket Connected!")
        
        // 연결 즉시 큐 비우기 및 API 키 전송
        flushQueue()
        sendAPIKey()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }
    
    // MARK: - 메시지 수신 (백엔드 → 클라이언트)
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("WebSocket Receive Error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isConnected = false }
                
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingJSON(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingJSON(text)
                    }
                @unknown default:
                    break
                }
                
                // 계속해서 수신 대기
                if self.isConnected {
                    self.receiveMessage()
                }
            }
        }
    }
    
    private func handleIncomingJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            let response = try JSONDecoder().decode(WSAgentResponse.self, from: data)
            print("[DEBUG-RX] Decoded: status=\(response.status), agent=\(response.agent_id), text=\(response.text.prefix(30))")
            
            DispatchQueue.main.async {
                let manager = AgentWindowManager.shared
                
                if response.status == "Thinking" {
                    self.currentSpeakerID = response.agent_id
                    self.agentStatus = "Thinking"
                    self.currentMessage = ""
                } else if response.status == "Speaking" {
                    self.currentSpeakerID = response.agent_id
                    self.agentStatus = "Speaking"
                    self.currentMessage = response.text
                    
                    // 하이브리드 음성 로직: 클라우드 보이스 사용이 켜져 있으면 AVAudioPlayer, 꺼져있으면 네이티브 TTS 재생
                    let useCloudVoice = UserDefaults.standard.bool(forKey: "useCloudVoice")
                    if useCloudVoice, let base64String = response.audio_base64, !base64String.isEmpty, let audioData = Data(base64Encoded: base64String) {
                        SpeechManager.shared.playAudioData(audioData)
                    } else if !useCloudVoice && !response.text.isEmpty {
                        // TODO: 필요하다면 agent_id에 따른 고유 Native Voice Identifier 맵핑 가능
                        SpeechManager.shared.speak(text: response.text)
                    }
                } else if response.status == "Idle" {
                    // 말하기가 끝났을 때 (Idle), 그동안의 메시지를 공용 로그에 저장
                    // 단, 시스템 자동 응답(is_system == true)은 로그에서 제외
                    if !self.currentMessage.isEmpty && !(response.is_system ?? false) {
                        let agentName = manager.activeAgents.first(where: { $0.id == response.agent_id })?.name ?? "에이전트"
                        let log = AgentWindowManager.ChatLog(
                            id: UUID(),
                            agentID: response.agent_id,
                            agentName: agentName,
                            text: self.currentMessage,
                            isUser: false,
                            timestamp: Date()
                        )
                        manager.teamChatLogs.append(log)
                    }
                    
                    self.currentSpeakerID = nil
                    self.currentMessage = ""
                    self.agentStatus = "Idle"
                    
                    // TTS가 재생 중일 수 있으므로 여기서 강제로 stopSpeaking()을 호출하지 않습니다.
                    // 만약 사용자가 대화를 중단하고 싶다면 별도의 중단 인터랙션에서 처리합니다.
                }
                
                // 텍스트 수신 시 소리 재생 (무음 모드가 아닐 때만)
                if response.status == "Speaking" && !manager.isSilentMode {
                    SoundPlayer.playDragStart(soundName: "Ping") 
                }
            }
        } catch {
            print("[DEBUG-RX] JSON Decode Error: \(error)")
            print("[DEBUG-RX] Raw JSON: \(jsonString.prefix(200))")
        }
    }
    
    // MARK: - 메시지 발신 (클라이언트 → 백엔드)
    // 현재는 테스트용 텍스트. 나중에는 오디오 청크를 보냄.
    func sendMessage(_ text: String, targetAgentID: String? = nil) {
        AgentWindowManager.shared.updateInteractionTime()
        guard isConnected else {
            print("WebSocket is disconnected. Reconnecting...")
            connect()
            return
        }
        
        var payload: [String: Any] = [
            "type": "user_command",
            "text": text,
            "use_cloud_voice": UserDefaults.standard.bool(forKey: "useCloudVoice"),
            "user_title": UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"
        ]
        
        if let targetAgentID = targetAgentID {
            payload["agent_id"] = targetAgentID
            
            // AppStorage(UserDefaults)에 저장된 해당 에이전트의 맞춤 성격 조회 및 주입
            let customPersona = UserDefaults.standard.string(forKey: "custom_persona_\(targetAgentID)") ?? ""
            if !customPersona.isEmpty {
                payload["custom_persona"] = customPersona
            }
        }
        
        // 전송 즉시 팀 로그(전역)에 내 메시지 기록 (메인 스레드 보장)
        DispatchQueue.main.async {
            let log = AgentWindowManager.ChatLog(
                id: UUID(),
                agentID: "user",
                agentName: "나",
                text: text,
                isUser: true,
                timestamp: Date()
            )
            AgentWindowManager.shared.teamChatLogs.append(log)
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket Send Error: \(error)")
            }
        }
    }
    
    // 3개 API 키를 백엔드로 모두 전송
    func sendAPIKey() {
        let geminiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        let claudeKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        let openaiKey = UserDefaults.standard.string(forKey: "openaiAPIKey") ?? ""
        
        let payload: [String: Any] = [
            "type": "api_keys",
            "gemini": geminiKey,
            "claude": claudeKey,
            "openai": openaiKey
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("API Key 전송 에러: \(error)")
            } else {
                print("API Keys 전송 성공")
            }
        }
    }
    
    // 시스템 이벤트 (잠금 해제, 시작 등) 전송
    func sendSystemEvent(eventType: String, baseGreeting: String, agentID: String? = nil) {
        let useCloudVoice = UserDefaults.standard.bool(forKey: "useCloudVoice")
        
        var payload: [String: Any] = [
            "type": "system_event",
            "event": eventType,
            "base_greeting": baseGreeting,
            "use_cloud_voice": useCloudVoice,
            "user_title": UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"
        ]
        
        if let aid = agentID {
            payload["agent_id"] = aid
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        print("[DEBUG-TX] sendSystemEvent: type=\(eventType), connected=\(isConnected)")
        
        if isConnected {
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("[DEBUG-TX] System Event 전송 에러: \(error)")
                } else {
                    print("[DEBUG-TX] System Event 전송 성공: \(eventType)")
                }
            }
        } else {
            print("[DEBUG-TX] WebSocket disconnected. Queuing: \(eventType)")
            messageQueue.append(message)
            connect()
        }
    }
    
    private func flushQueue() {
        guard isConnected, !messageQueue.isEmpty else { return }
        print("Flushing WebSocket queue (\(messageQueue.count) messages)")
        while !messageQueue.isEmpty {
            let msg = messageQueue.removeFirst()
            webSocketTask?.send(msg) { error in
                if let error = error {
                    print("Queue Flush Error: \(error)")
                }
            }
        }
    }
}
