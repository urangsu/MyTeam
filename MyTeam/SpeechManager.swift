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
            let playbackStreamID = UUID().uuidString

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
                            // Round 266: agentID 전달 — 캐릭터별 preset/emotion/pitch/rate/speed 적용
                            await self.dispatchToInferencePipeline(
                                text: ttsChunk,
                                characterName: characterName,
                                agentID: agentID,
                                streamId: playbackStreamID,
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
                    // Round 266: agentID 전달 (자투리 문장도 동일하게)
                    await self.dispatchToInferencePipeline(
                        text: ttsRemainder,
                        characterName: characterName,
                        agentID: agentID,
                        streamId: playbackStreamID,
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
        agentID: String? = nil,
        streamId: String? = nil,
        onPlaybackStarted: @escaping @Sendable () -> Void
    ) async {
        // Supertonic3 ONNX pipeline removed — silent playback
        AppLog.info("[SpeechManager] Supertonic3 ONNX pipeline removed — silent playback")
        onPlaybackStarted()
    }

    // MARK: - 권한 요청
    // Round 278 3-A: 거부 시 사용자에게 보여줄 안내(throttle 적용)를 함께 반환.
    private static var lastDenialNoticeShownAt: Date? = nil
    private static let denialThrottleSeconds: TimeInterval = 300  // 5분
    private static let micDenialGuidance =
        "음성 입력 권한이 꺼져 있어요. 시스템 설정 → 개인정보 보호 → 마이크에서 MyTeam을 켜주세요."

    /// 기존 호출자 호환 — granted만 반환.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        requestAuthorization { granted, _ in completion(granted) }
    }

    /// Round 278 3-A: 거부 시 안내 메시지를 함께 전달. throttle 후엔 guidance == nil.
    func requestAuthorization(completion: @escaping (_ granted: Bool, _ guidance: String?) -> Void) {
        Task {
            let granted = await PermissionsManager.shared.requestAllAudioPermissions()
            var guidance: String? = nil
            if !granted {
                let now = Date()
                let throttled: Bool = {
                    guard let last = Self.lastDenialNoticeShownAt else { return false }
                    return now.timeIntervalSince(last) < Self.denialThrottleSeconds
                }()
                if !throttled {
                    guidance = Self.micDenialGuidance
                    Self.lastDenialNoticeShownAt = now
                }
            }
            await MainActor.run { completion(granted, guidance) }
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
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[!?]{2,}", with: "!", options: .regularExpression)
            .replacingOccurrences(of: "\\.{2,}", with: ".", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.contains(where: { $0.isTTSMeaningfulCharacter }) else {
            return nil
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
            // Round 256TTS-OFFICIAL-ENGINE: Supertonic3 공식 경로 사용.
            // Apple TTS 폴백 없음. provider 없으면 무음.
            await dispatchToInferencePipeline(
                text: text,
                characterName: character,
                agentID: agentID,
                onPlaybackStarted: {}
            )
            await MainActor.run { self.isSpeaking = false }
        }
    }

    // MARK: - Round 257TTS-PLAYBACK: 합성 + 재생 단일 API

    /// 단발성 TTS: 합성 → AudioPlaybackService 재생 → TTSOutput 반환.
    /// SpeakButtonView 등 명시적 사용자 액션에서 호출. launch auto-init 없음.
    /// - Returns: 합성+재생 성공 시 TTSOutput, 실패(라우팅 실패/합성 오류) 시 nil
    func speakOnce(text: String, agentID: String? = nil) async -> TTSOutput? {
        // Supertonic3 ONNX pipeline removed
        return nil
    }

    /// 원본 Preset 미리듣기 — 캐릭터 pitch/rate/speed 보정 없이 순수 preset 목소리 재생.
    /// TTS Lab "원본 Preset 테스트" 전용. pitch=0, rate=1로 재생.
    func previewPreset(text: String, preset: String, speed: Float = 1.05) async -> TTSOutput? {
        return nil
    }

    /// 감정 표현 미리듣기 — 지정 agentID 캐릭터의 특정 emotion style로 발화.
    /// TTS Lab "감정 표현 테스트" 전용.
    func previewCharacterEmotion(text: String, agentID: String, emotion: SupertonicEmotionStyle) async -> TTSOutput? {
        return nil
    }

    /// P/R/S 임시 튜닝 적용 미리듣기.
    /// TTS Lab "임시 P/R/S 튜닝" toggle이 ON일 때 사용.
    func previewWithTuning(
        text: String,
        preset: String,
        pitch: Float,
        rate: Float,
        speed: Float,
        emotion: SupertonicEmotionStyle = .neutral,
        agentID: String? = nil,
        label: String = "tuning_preview",
        useExpressionTags: Bool = false
    ) async -> TTSOutput? {
        return nil
    }

    /// Procedural Animalese 미리듣기. Supertonic3ONNXRunner 사용하지 않음.
    /// 모델 없어도 동작. TTS routing 정책과 독립. TTS Lab 테스트 전용.
    /// 기본 채팅 발화에는 사용하지 않음.
    func previewAnimalese(
        text: String,
        profile: AnimaleseVoiceProfile,
        speed: Float,
        pitchOffset: Float = 0,
        label: String = "animalese"
    ) async -> TTSOutput? {
        let normalized = Self.normalizedTTSChunk(text) ?? "audio path test"
        let sampleRate = 44_100
        let clampedSpeed = max(0.55, min(1.6, Double(speed)))
        let baseFrequency = profile.baseFrequency * pow(2.0, Double(pitchOffset) / 1200.0)
        let charDuration = max(0.035, min(0.12, profile.charDuration / clampedSpeed))
        let gapDuration = max(0.004, 0.012 / clampedSpeed)

        var samples: [Float] = []
        samples.reserveCapacity(min(180_000, normalized.count * Int(charDuration * Double(sampleRate))))

        for (index, character) in normalized.enumerated() {
            if character.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) {
                samples.append(contentsOf: Array(repeating: 0, count: Int(0.045 * Double(sampleRate))))
                continue
            }

            let scalarSeed = character.unicodeScalars.first.map { Int($0.value % 17) } ?? 0
            let phraseBend = sin(Double(index) * 0.62) * 12.0
            let frequency = baseFrequency + Double(scalarSeed * 9) + phraseBend
            let frameCount = Int(charDuration * Double(sampleRate))

            for frame in 0..<frameCount {
                let t = Double(frame) / Double(sampleRate)
                let progress = Double(frame) / Double(max(frameCount - 1, 1))
                let attack = min(1.0, progress / 0.16)
                let release = min(1.0, (1.0 - progress) / 0.22)
                let envelope = min(attack, release) * 0.20
                let primary = sin(2.0 * .pi * frequency * t)
                let overtone = sin(2.0 * .pi * frequency * 2.01 * t) * 0.22
                samples.append(Float((primary + overtone) * envelope))
            }

            samples.append(contentsOf: Array(repeating: 0, count: Int(gapDuration * Double(sampleRate))))
        }

        guard !samples.isEmpty else { return nil }
        let didStart = await playback.playFloatSamples(
            samples: samples,
            sampleRate: sampleRate,
            streamId: UUID().uuidString,
            characterName: "audio_path_test",
            pitch: pitchOffset,
            rate: Float(clampedSpeed),
            onPlaybackStarted: {}
        )
        guard didStart else { return nil }
        return TTSOutput(audioFileURL: nil, duration: Double(samples.count) / Double(sampleRate), sampleRate: sampleRate, providerKind: .supertonic3)
    }

    /// 단발성 공식 TTS 합성. 반환값: WAV 파일 경로 (nil=무음 또는 실패).
    /// 호출 시점에만 Supertonic3ONNXRunner.shared.synthesize 실행. launch auto-init 없음.
    func synthesize(text: String, agentID: String? = nil) async -> TTSOutput? {
        return nil
    }

    // MARK: - Barge-in 격추 시스템
    func abortPipelinedStream() {
        currentStreamTask?.cancel()
        currentStreamTask = nil

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
        let aliases = CharacterDisplayNameResolver.localizedAliases(for: characterName)
        for alias in aliases {
            if let style = styles[alias] {
                return style.clamped
            }
        }
        let canonical = CharacterDisplayNameResolver.canonicalID(for: characterName)
        let localizedName = CharacterDisplayNameResolver.displayName(for: canonical)
        return (styles[characterName] ?? styles[localizedName] ?? .neutral).clamped
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
