import Foundation
import Combine
import AppKit
import AVFoundation

// MARK: - SpeechManager (MLX Native 오케스트레이터)
// 역할: 텍스트 전처리 → MLX-Swift 네이티브 스트리밍 엔진으로 즉각 라우팅
// 캐시/레거시 파일 I/O 파이프라인 완전 폐기 (FP16 상시 적재 방식 적용)
final class SpeechManager: ObservableObject, @unchecked Sendable {
    static let shared = SpeechManager()

    // MARK: - Published State
    @Published var isSpeaking: Bool = false
    @Published var isRecording: Bool = false
    @Published var isStarting: Bool = false
    @Published var recognizedText: String = ""
    @Published var sttError: String? = nil

    // MARK: - Callbacks
    var onAudioStarted: (() -> Void)?

    // MARK: - Services (DI)
    private let capture: AudioCaptureService
    private let playback: AudioPlaybackService
    private let inference: MLXInferenceService

    // MARK: - Internal State
    private var speakDebounceTimer: DispatchWorkItem?
    private var currentSpeakingAgentID: String? = nil
    private var currentStreamTask: Task<Void, Never>? = nil

    // MARK: - Init
    private init() {
        self.capture = AudioCaptureService.shared
        self.playback = AudioPlaybackService.shared
        self.inference = MLXInferenceService.shared

        // AudioCaptureService 상태 
        capture.$isRecording.assign(to: &$isRecording)
        capture.$isStarting.assign(to: &$isStarting)
        capture.$recognizedText.assign(to: &$recognizedText)
        capture.$sttError.assign(to: &$sttError)

        // Barge-in 방어막: 즉각 추론 취소
        capture.onBargeInDetected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let isAIPlaying = await self.playback.isCurrentlyPlaying
                guard isAIPlaying else { return }
                print("[SpeechManager] 🎙️ Barge-in 발생 → MLX 추론 스트림 격추")
                self.stopSpeaking()
            }
        }
    }

    // MARK: - 권한 요청
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        Task {
            let granted = await PermissionsManager.shared.requestAllAudioPermissions()
            await MainActor.run { completion(granted) }
        }
    }

    func startRecording() { capture.startRecording() }
    func stopRecording()  { capture.stopRecording() }

    // MARK: - 메인 TTS 연결부
    func speak(text: String, agentID: String? = nil, characterName: String? = nil, voiceIdentifier: String? = nil) {
        guard !AgentWindowManager.shared.isSilentMode else { return }
        speakDebounceTimer?.cancel()

        Task { await playback.stopAll() }
        currentStreamTask?.cancel()

        let clean = sanitize(text)
        guard !clean.isEmpty else { return }

        let character = characterName ?? (AgentWindowManager.shared.activeAgents.first?.name ?? "루나")
        let ttsText = shorten(clean)

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.currentSpeakingAgentID = agentID
            self.isSpeaking = true
            self.executeNativeInference(text: ttsText, characterName: character, agentID: agentID)
        }
        speakDebounceTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    func speakImmediate(text: String, agentID: String? = nil, characterName: String? = nil) {
        guard !AgentWindowManager.shared.isSilentMode else { return }
        speakDebounceTimer?.cancel()
        currentStreamTask?.cancel()
        
        let clean = sanitize(text)
        guard !clean.isEmpty else { return }
        let character = characterName ?? "루나"
        currentSpeakingAgentID = agentID
        isSpeaking = true
        executeNativeInference(text: shorten(clean), characterName: character, agentID: agentID)
    }

    @MainActor
    func speakChunk(text: String, agentID: String, characterName: String,
                    onStart: @escaping () -> Void) async -> Bool {
        let clean = sanitize(text)
        let ttsText = shorten(clean)
        guard !ttsText.isEmpty else { return false }
        
        onStart()
        self.onAudioStarted?(); self.onAudioStarted = nil
        
        self.currentSpeakingAgentID = agentID
        self.isSpeaking = true
        self.executeNativeInference(text: ttsText, characterName: characterName, agentID: agentID)
        
        return true
    }

    // MARK: - MLXInferenceService AsyncStream 주입
    private func executeNativeInference(text: String, characterName: String, agentID: String?) {
        let streamId = "mlx_stream_\(UUID().uuidString)"
        
        // 피치 등 설정 (차후 MLX 전용 VoiceConfig로 편입 예정)
        let profile = AnimalTTSManager.profile(for: characterName)
        
        currentStreamTask = Task {
            // 1. 제너레이터에서 C레벨 토큰 스트림 오픈
            let pcmStream = await inference.generateTTSStream(text: text, characterName: characterName)
            
            // 2. Playback 쪽으로 구독 (Consume) 배관 연결
            await playback.playStream(
                streamId: streamId,
                stream: pcmStream,
                characterName: characterName,
                pitch: profile.pitch,
                rate: 1.0
            )
            
            await MainActor.run {
                self.finishSpeaking(agentID: agentID)
            }
        }
    }

    func prefetchChunk(text: String, characterName: String) {
        // 프리베이크 무효화로 인한 No-op
    }

    // MARK: - 중지 제어 (Abort)
    func stopSpeaking() {
        speakDebounceTimer?.cancel(); speakDebounceTimer = nil
        currentStreamTask?.cancel()
        
        Task { await playback.stopAll() }
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.finishSpeaking(agentID: self.currentSpeakingAgentID)
        }
    }

    func stopChunkSpeaking() { stopSpeaking() }
    func stopEffectEngine()  { stopSpeaking() }

    func playAudioData(_ data: Data) { }
    
    // MARK: - 유틸리티
    private func sanitize(_ text: String) -> String { return TextSanitizer.sanitize(text) }
    private func shorten(_ text: String) -> String {
        return text.count > 100 ? String(text.prefix(100)) + "..." : text
    }

    private func finishSpeaking(agentID: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            if let id = agentID, AgentWindowManager.shared.speakingAgentID == id {
                AgentWindowManager.shared.speakingAgentID = nil
            }
        }
    }
}
