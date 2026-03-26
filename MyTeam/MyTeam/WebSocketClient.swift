import Foundation
import Combine

// MARK: - WebSocketMessage
// 백엔드와 주고받을 메시지 구조체
struct WSAgentResponse: Codable {
    let type: String
    let agent_id: String
    let text: String
    let status: String
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
    
    private init() {
        connect()
    }
    
    func connect() {
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        receiveMessage()
        print("WebSocket Connected!")
        
        // 연결되자마자 저장된 API 키를 서버로 전송
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
                } else if response.status == "Idle" {
                    // 말하기가 끝났을 때 (Idle), 그동안의 메시지를 공용 로그에 저장
                    if !self.currentMessage.isEmpty {
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
                }
                
                // 텍스트 수신 시 소리 재생 (무음 모드가 아닐 때만)
                if response.status == "Speaking" && !manager.isSilentMode {
                    SoundPlayer.playDragStart(soundName: "Ping") 
                }
            }
        } catch {
            print("JSON Decode Error: \(error)")
        }
    }
    
    // MARK: - 메시지 발신 (클라이언트 → 백엔드)
    // 현재는 테스트용 텍스트. 나중에는 오디오 청크를 보냄.
    func sendMessage(_ text: String, targetAgentID: String? = nil) {
        guard isConnected else {
            print("WebSocket is disconnected. Reconnecting...")
            connect()
            return
        }
        
        var payload: [String: Any] = [
            "type": "user_command",
            "text": text
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
}
