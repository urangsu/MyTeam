import Foundation
import AVFoundation
import Combine

// MARK: - LiveAudioManager
// Gemini Multimodal Live API 전용 WebSocket 클라이언트.
// 기존 STT(Apple) → 텍스트를 /ws/live 엔드포인트로 전송,
// Gemini Live가 생성한 음성(WAV)을 수신해 바로 재생합니다.
// 녹음 시작 시 자동으로 interrupt 신호를 보내 바지인(Barge-in)을 구현합니다.
class LiveAudioManager: NSObject, ObservableObject {

    static let shared = LiveAudioManager()

    // ── 상태 ──
    @Published var isLiveModeEnabled: Bool = false
    @Published var isConnected: Bool = false
    @Published var currentSpeakerID: String? = nil
    @Published var currentMessage: String = ""
    @Published var agentStatus: String = "Idle"

    // ── WebSocket ──
    private var webSocketTask: URLSessionWebSocketTask?
    private var liveURL: URL {
        let base = UserDefaults.standard.string(forKey: "customBackendURL") ?? "ws://127.0.0.1:8000/ws"
        let live = base.replacingOccurrences(of: "/ws", with: "/ws/live")
        return URL(string: live) ?? URL(string: "ws://127.0.0.1:8000/ws/live")!
    }

    // ── 오디오 플레이어 (Gemini Live 음성 수신용) ──
    private var audioPlayer: AVAudioPlayer?

    private override init() {
        super.init()
        // 설정 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiveModeChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        isLiveModeEnabled = UserDefaults.standard.bool(forKey: "useLiveMode")
    }

    @objc private func handleLiveModeChange() {
        let newValue = UserDefaults.standard.bool(forKey: "useLiveMode")
        if newValue != isLiveModeEnabled {
            isLiveModeEnabled = newValue
            if newValue {
                connect()
            } else {
                disconnect()
            }
        }
    }

    // MARK: - 연결
    func connect() {
        guard isLiveModeEnabled else { return }
        if isConnected { return }

        let request = URLRequest(url: liveURL)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveMessage()
        print("[Live] Connecting to \(liveURL)…")
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - 메시지 수신
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                print("[Live] Receive error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isConnected = false }

            case .success(let message):
                if !self.isConnected {
                    DispatchQueue.main.async {
                        self.isConnected = true
                        print("[Live] Connected")
                        self.sendAPIKey()
                    }
                }

                switch message {
                case .string(let text):
                    self.handleJSON(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleJSON(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()
            }
        }
    }

    private func handleJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(WSAgentResponse.self, from: data)
        else { return }

        print("[Live-RX] status=\(response.status), agent=\(response.agent_id)")

        DispatchQueue.main.async {
            let manager = AgentWindowManager.shared

            switch response.status {
            case "Thinking":
                self.currentSpeakerID = response.agent_id
                self.agentStatus = "Thinking"
                self.currentMessage = ""

            case "Speaking":
                self.currentSpeakerID = response.agent_id
                self.agentStatus = "Speaking"
                self.currentMessage = response.text

                // Gemini Live 음성(WAV) 재생
                if let b64 = response.audio_base64, !b64.isEmpty,
                   let audioData = Data(base64Encoded: b64) {
                    self.playAudio(audioData)
                }

            case "Idle":
                // 에이전트 로그 저장 (is_system 제외)
                if !self.currentMessage.isEmpty && !(response.is_system ?? false) {
                    let agentName = manager.activeAgents.first(where: { $0.id == response.agent_id })?.name ?? "에이전트"
                    manager.addChatLog(
                        agentID: response.agent_id,
                        agentName: agentName,
                        text: self.currentMessage,
                        isUser: false
                    )
                }
                self.currentSpeakerID = nil
                self.currentMessage = ""
                self.agentStatus = "Idle"

            default:
                break
            }
        }
    }

    // MARK: - 메시지 발신

    /// 텍스트를 Gemini Live 엔드포인트로 전송
    func sendText(_ text: String, targetAgentID: String? = nil) {
        guard isLiveModeEnabled else { return }

        var payload: [String: Any] = [
            "type": "user_command",
            "text": text,
            "use_audio": true,   // Gemini Live가 음성으로 응답
            "user_title": UserDefaults.standard.string(forKey: "userTitle") ?? "사용자님"
        ]

        if let id = targetAgentID {
            payload["agent_id"] = id
            let persona = UserDefaults.standard.string(forKey: "custom_persona_\(id)") ?? ""
            if !persona.isEmpty { payload["custom_persona"] = persona }
            let role = UserDefaults.standard.string(forKey: "delegation_role_\(id)") ?? ""
            if !role.isEmpty { payload["delegation_role"] = role }
        }

        send(payload)
    }

    /// 바지인(Barge-in): 현재 에이전트 응답을 즉시 중단
    func sendInterrupt() {
        guard isLiveModeEnabled, isConnected else { return }
        // 오디오 즉시 정지
        audioPlayer?.stop()
        audioPlayer = nil

        let payload: [String: Any] = ["type": "interrupt"]
        send(payload)
        print("[Live] Barge-in interrupt sent")
    }

    /// API 키 전송
    func sendAPIKey() {
        let payload: [String: Any] = [
            "type": "api_keys",
            "gemini":  KeychainManager.load(key: "geminiAPIKey"),
            "claude":  KeychainManager.load(key: "claudeAPIKey"),
            "openai":  KeychainManager.load(key: "openaiAPIKey")
        ]
        send(payload)
    }

    private func send(_ payload: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        if isConnected {
            webSocketTask?.send(message) { error in
                if let error = error { print("[Live] Send error: \(error)") }
            }
        } else {
            connect()
        }
    }

    // MARK: - 오디오 재생 (Gemini Live → WAV)
    private func playAudio(_ data: Data) {
        audioPlayer?.stop()
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("[Live] Audio play error: \(error)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension LiveAudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer = nil
    }
}
