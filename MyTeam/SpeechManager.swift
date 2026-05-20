import Foundation
import Combine
import AppKit

// MARK: - SpeechManager (Perfect Lip-Sync + Barge-in 지원 백그라운드 오케스트레이터)
// 핵심 원칙:
//   ✅텍스트는 오디오가 스피커에서 재생 시작될 때만 화면에 표시됨
//   ✅SSE 청크 분리/MLX 추론/AudioPlayback 배관은 모두 백그라운드에서만 동작
//   ✅UI(AgentChatView)는 onPlaybackStarted 콜백을 받아 말풍선을 그리기만 함
final class SpeechManager: ObservableObject, @unchecked Sendable {
    static let shared = SpeechManager()

    // MARK: - Published State
    @Published var isSpeaking: Bool = false
    @Published var isRecording: Bool = false
    @Published var isStarting: Bool = false
    @Published var recognizedText: String = ""
    @Published var sttError: String? = nil

    var onAudioStarted: (() -> Void)?

    private let capture = AudioCaptureService.shared
    private let playback = AudioPlaybackService.shared

    private var currentStreamTask: Task<Void, Never>? = nil
    private var currentSpeakingAgentID: String? = nil

    /// Qwen3 TTS — Developer Lab override + 실험 플래그 두 가지 모두 켜져야 활성.
    /// Round 247TTS: ttsDevLabQwen3Override 없이는 enableExperimentalQwenTTS만으로 활성화 불가.
    /// TTSRoutingPolicy.selectedProvider()와 동일 로직 유지.
    private var qwenEnabled: Bool {
        TTSRoutingPolicy.selectedProvider() == .qwen3MLX
    }
    /// 세션 내 Qwen3 불가 캐시 — 한 번 실패하면 세션 내 재시도 없음
    private var qwenUnavailable: Bool = false

    /// 진단: Qwen TTS 활성화 여부 및 세션 내 비가용 캐시 상태
    var qwenDiagnostics: (enabled: Bool, unavailable: Bool) {
        (qwenEnabled, qwenUnavailable)
    }

    private init() {
        capture.$isRecording.assign(to: &$isRecording)
        capture.$isStarting.assign(to: &$isStarting)
        capture.$recognizedText.assign(to: &$recognizedText)
        capture.$sttError.assign(to: &$sttError)

        // 🛑 Barge-in: 마이크 입력 감지 즉시 전체 파이프라인 격추
        capture.onBargeInDetected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard await self.playback.isCurrentlyPlaying else { return }
                print("[SpeechManager] 🎙️ Barge-in 감지 → MLX 추론 + 오디오 엔진 즉각 격추")
                self.abortPipelinedStream()
            }
        }
    }

    // MARK: - 🎯 Perfect Lip-Sync SSE 스트리밍 파이프라인
    /// AIService SSE 토큰 스트림 → 문장 분리 → MLX 추론 → 오디오 재생 시작 시점에 UI 텍스트 표시
    ///
    /// - Parameters:
    ///   - agentID: 말하는 에이전트 ID
    ///   - characterName: TTS 레퍼런스 오디오 선택에 사용되는 이름
    ///   - tokenStream: AIService.getResponseStream()에서 반환된 SSE 토큰 스트림
    ///   - onAudioPlaybackStarted: 오디오가 스피커에서 '재생 시작'될 때 호출되는 UI 콜백
    ///                             인자: 해당 청크의 원본 텍스트 (말풍선에 표시할 문장)
    func processRealtimeSSEStream(
        agentID: String,
        characterName: String,
        tokenStream: AsyncThrowingStream<String, Error>,
        onAudioPlaybackStarted: @escaping @Sendable (String) -> Void
    ) {
        abortPipelinedStream()

        currentSpeakingAgentID = agentID
        DispatchQueue.main.async { self.isSpeaking = true }

        currentStreamTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var sentenceBuffer = ""

            do {
                for try await token in tokenStream {
                    if Task.isCancelled { break }

                    sentenceBuffer += token

                    // 문장 경계(마침표, 물음표, 느낌표, 개행) 감지 시 즉각 청크 처리
                    if sentenceBuffer.contains(where: { [".", "?", "!", "\n", "。"].contains($0) }) {
                        let chunk = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                        sentenceBuffer = "" // 버퍼 즉시 플러시

                        if let ttsChunk = Self.normalizedTTSChunk(chunk), !Task.isCancelled {
                            // ✅ 핵심: UI 콜백을 여기서 직접 호출하지 않음
                            // 대신 오디오 재생 시작 시점에 실행될 클로저를 파이프라인에 주입
                            await self.dispatchToInferencePipeline(
                                text: ttsChunk,
                                characterName: characterName,
                                onPlaybackStarted: {
                                    // 이 클로저는 playerNode.play() 직후 AudioPlaybackService가 호출
                                    // ← 이 시점이 텍스트가 화면에 나타나야 하는 정확한 순간
                                    onAudioPlaybackStarted(ttsChunk)
                                }
                            )
                        }
                    }
                }

                // 자투리 미완성 문장 처리
                let remainder = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if let ttsRemainder = Self.normalizedTTSChunk(remainder), !Task.isCancelled {
                    await self.dispatchToInferencePipeline(
                        text: ttsRemainder,
                        characterName: characterName,
                        onPlaybackStarted: { onAudioPlaybackStarted(ttsRemainder) }
                    )
                }

            } catch {
                print("[SpeechManager] 🚨 SSE 스트림 에러: \(error.localizedDescription)")
            }

            await MainActor.run { self.isSpeaking = false }
        }
    }

    // MARK: - 추론-재생 배관 (내부 전용)
    private func dispatchToInferencePipeline(
        text: String,
        characterName: String,
        onPlaybackStarted: @escaping @Sendable () -> Void
    ) async {
        // ── TTSRoutingPolicy 기반 provider 선택 (Round 247TTS) ──
        // Apple TTS (AVSpeechSynthesizer)는 이 switch에 없음 — 프로젝트 정책: 절대 금지.
        switch TTSRoutingPolicy.selectedProvider() {

        case .supertonic3:
            // Cloud 환경: missingRuntime → 무음. Mac 248TTS 이후: 실제 inference.
            AppLog.info("[AICall] callType=tts provider=supertonic3 (skeleton, Cloud: silent)")
            do {
                _ = try await Supertonic3TTSProvider.shared.synthesize(text: text)
            } catch {
                AppLog.info("[SpeechManager] Supertonic3 unavailable: \(error) → silent")
            }
            onPlaybackStarted()

        case .qwen3MLX:
            // Developer Lab override 전용. 세션 내 불가 캐시 확인.
            guard !qwenUnavailable else {
                AppLog.info("[AICall] callType=tts skipped (qwen3Unavailable)")
                onPlaybackStarted()
                return
            }
            let streamId = "mlx_\(UUID().uuidString)"
            AppLog.info("[AICall] callType=tts provider=qwen3MLX characterName=\(characterName)")
            let pcmStream = Qwen3TTSService.shared.generateTTSStream(text: text, characterName: characterName)
            let style = VoiceStyleCatalog.playbackStyle(for: characterName)
            await playback.playStream(
                streamId: streamId,
                stream: pcmStream,
                characterName: characterName,
                pitch: style.pitch,
                rate: style.rate,
                textPayload: text,
                onPlaybackStarted: onPlaybackStarted
            )

        case .none:
            // 무음 — provider 없음. Apple TTS 폴백 없음.
            AppLog.info("[AICall] callType=tts skipped (noProvider → silent)")
            onPlaybackStarted()
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

    // MARK: - 단발성 TTS (레거시 호환 - Silent Mode, 팀채팅 등)
    private func chunkText(_ text: String) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        for char in text {
            currentChunk.append(char)
            if char == "." || char == "?" || char == "!" || char == "\n" {
                let trimmed = currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if let normalized = Self.normalizedTTSChunk(trimmed) { chunks.append(normalized) }
                currentChunk = ""
            }
        }
        let finalTrimmed = currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized = Self.normalizedTTSChunk(finalTrimmed) { chunks.append(normalized) }
        return chunks
    }

    private nonisolated static func normalizedTTSChunk(_ text: String) -> String? {
        var normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[!?]{2,}", with: "!", options: .regularExpression)
            .replacingOccurrences(of: "\\.{2,}", with: ".", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.contains(where: { $0.isTTSMeaningfulCharacter }) else {
            return nil
        }

        if normalized.count > 90 {
            normalized = String(normalized.prefix(90)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return normalized.isEmpty ? nil : normalized
    }

    func speak(text: String, agentID: String? = nil, characterName: String? = nil) {
        guard !AgentWindowManager.shared.isSilentMode else { return }
        let character = characterName
            ?? agentID.flatMap { id in
                AgentWindowManager.shared.allAvailableAgents.first(where: { $0.id == id })?.name
            }
            ?? "루나"
        currentSpeakingAgentID = agentID
        DispatchQueue.main.async { self.isSpeaking = true }

        currentStreamTask = Task {
            let provider = TTSRoutingPolicy.selectedProvider()
            // 무음 처리 (Apple TTS 폴백 없음)
            guard provider == .qwen3MLX else {
                AppLog.info("[AICall] callType=tts skipped speak() (provider=\(String(describing: provider)) → silent)")
                await MainActor.run { self.isSpeaking = false }
                return
            }
            guard !self.qwenUnavailable else {
                AppLog.info("[AICall] callType=tts skipped speak() (qwen3Unavailable)")
                await MainActor.run { self.isSpeaking = false }
                return
            }
            let sentences = self.chunkText(text)
            for sentence in sentences {
                if Task.isCancelled { break }
                let streamId = "mlx_\(UUID().uuidString)"
                AppLog.info("[AICall] callType=tts provider=qwen3MLX characterName=\(character)")
                let pcmStream = Qwen3TTSService.shared.generateTTSStream(text: sentence, characterName: character)
                let style = VoiceStyleCatalog.playbackStyle(for: character)
                await playback.playStream(streamId: streamId, stream: pcmStream,
                                          characterName: character, pitch: style.pitch, rate: style.rate)
            }
            await MainActor.run { self.isSpeaking = false }
        }
    }

    // MARK: - Barge-in 격추 시스템
    func abortPipelinedStream() {
        currentStreamTask?.cancel()
        currentStreamTask = nil

        // MLX 추론 루프 취소 — qwen3MLX provider일 때만 (다른 provider 상태에서 cancel 로그 방지)
        if TTSRoutingPolicy.selectedProvider() == .qwen3MLX {
            Task { await Qwen3TTSService.shared.cancelCurrentInference() }
        }

        // 오디오 엔진 즉각 정지
        Task { await playback.stopAll() }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            if AgentWindowManager.shared.speakingAgentID == self.currentSpeakingAgentID {
                AgentWindowManager.shared.speakingAgentID = nil
            }
        }
    }

    func stopSpeaking() { abortPipelinedStream() }
    func stopChunkSpeaking() { abortPipelinedStream() }
    func prefetchChunk(text: String, characterName: String) { /* No-op: 레거시 호환 */ }
    func playAudioData(_ data: Data) { /* No-op */ }
}

private struct VoicePlaybackStyle {
    let pitch: Float
    let rate: Float

    static let neutral = VoicePlaybackStyle(pitch: 0.0, rate: 1.0)

    var clamped: VoicePlaybackStyle {
        VoicePlaybackStyle(
            pitch: min(360, max(-300, pitch)),
            rate: min(1.14, max(0.90, rate))
        )
    }
}

private enum VoiceStyleCatalog {
    static func playbackStyle(for characterName: String) -> VoicePlaybackStyle {
        guard UserDefaults.standard.bool(forKey: "useAnimalCrossingTTS") else {
            return .neutral
        }
        return (styles[characterName] ?? .neutral).clamped
    }

    private static let styles: [String: VoicePlaybackStyle] = [
        "치코": VoicePlaybackStyle(pitch: 260, rate: 1.08),
        "레오": VoicePlaybackStyle(pitch: -180, rate: 0.94),
        "루나": VoicePlaybackStyle(pitch: 180, rate: 1.03),
        "렉스": VoicePlaybackStyle(pitch: -260, rate: 0.92),
        "핀": VoicePlaybackStyle(pitch: 320, rate: 1.10),
        "모코": VoicePlaybackStyle(pitch: 90, rate: 0.97),
        "케이": VoicePlaybackStyle(pitch: -120, rate: 0.98),
        "래키": VoicePlaybackStyle(pitch: 120, rate: 1.06),
        "폴라": VoicePlaybackStyle(pitch: -180, rate: 0.94),
        "몽몽": VoicePlaybackStyle(pitch: 340, rate: 1.12),
        "올리버": VoicePlaybackStyle(pitch: -80, rate: 0.96)
    ]
}

private extension Character {
    nonisolated var isTTSMeaningfulCharacter: Bool {
        unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || (0xAC00...0xD7AF).contains(Int(scalar.value))
                || (0x1100...0x11FF).contains(Int(scalar.value))
                || (0x3130...0x318F).contains(Int(scalar.value))
        }
    }
}
