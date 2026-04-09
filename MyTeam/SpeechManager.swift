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

                        if !chunk.isEmpty && !Task.isCancelled {
                            // ✅ 핵심: UI 콜백을 여기서 직접 호출하지 않음
                            // 대신 오디오 재생 시작 시점에 실행될 클로저를 파이프라인에 주입
                            await self.dispatchToInferencePipeline(
                                text: chunk,
                                characterName: characterName,
                                onPlaybackStarted: {
                                    // 이 클로저는 playerNode.play() 직후 AudioPlaybackService가 호출
                                    // ← 이 시점이 텍스트가 화면에 나타나야 하는 정확한 순간
                                    onAudioPlaybackStarted(chunk)
                                }
                            )
                        }
                    }
                }

                // 자투리 미완성 문장 처리
                let remainder = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !remainder.isEmpty && !Task.isCancelled {
                    await self.dispatchToInferencePipeline(
                        text: remainder,
                        characterName: characterName,
                        onPlaybackStarted: { onAudioPlaybackStarted(remainder) }
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
        let streamId = "mlx_\(UUID().uuidString)"

        // MLX Inference: 텍스트 → PCM AsyncStream
        let pcmStream = await MLXInferenceService.shared.generateTTSStream(text: text, characterName: characterName)

        // AudioPlaybackService: PCM 스트림 소비 + 재생 시작 시 Lip-Sync 콜백 발화
        // onPlaybackStarted는 playStream → appendRawPCM → playerNode.play() 직후 트리거됨
        await playback.playStream(
            streamId: streamId,
            stream: pcmStream,
            characterName: characterName,
            pitch: 1.0,
            rate: 1.0,
            textPayload: text,
            onPlaybackStarted: onPlaybackStarted  // 🎯 이 콜백이 UI 말풍선을 그림
        )
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
    func speak(text: String, agentID: String? = nil, characterName: String? = nil) {
        guard !AgentWindowManager.shared.isSilentMode else { return }
        let character = characterName ?? "루나"
        currentSpeakingAgentID = agentID
        DispatchQueue.main.async { self.isSpeaking = true }

        currentStreamTask = Task {
            let streamId = "mlx_\(UUID().uuidString)"
            let pcmStream = await MLXInferenceService.shared.generateTTSStream(text: text, characterName: character)
            await playback.playStream(streamId: streamId, stream: pcmStream,
                                      characterName: character, pitch: 1.0, rate: 1.0)
            await MainActor.run { self.isSpeaking = false }
        }
    }

    // MARK: - Barge-in 격추 시스템
    func abortPipelinedStream() {
        currentStreamTask?.cancel()
        currentStreamTask = nil

        // MLX 추론 루프 취소
        Task { await MLXInferenceService.shared.cancelCurrentInference() }

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
