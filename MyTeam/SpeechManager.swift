import Foundation
import Combine
import AppKit

// MARK: - SpeechManager (Perfect Lip-Sync + Barge-in 지원 백그라운드 오케스트레이터)
// 핵심 원칙:
//   ✅텍스트는 오디오가 스피커에서 재생 시작될 때만 화면에 표시됨
//   ✅SSE 청크 분리/Supertonic3 추론/AudioPlayback 배관은 모두 백그라운드에서만 동작
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
            Task(priority: .userInitiated) { @MainActor [weak self] in
                guard let self else { return }
                guard await self.playback.isCurrentlyPlaying else { return }
                print("[SpeechManager] 🎙️ Barge-in 감지 → Supertonic3 추론 + 오디오 엔진 즉각 격추")
                self.abortPipelinedStream()
            }
        }
    }

    // MARK: - 🎯 Perfect Lip-Sync SSE 스트리밍 파이프라인
    /// AIService SSE 토큰 스트림 → 문장 분리 → Supertonic3 추론 → 오디오 재생 시작 시점에 UI 텍스트 표시
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

                        if let ttsChunk = Self.validatedTTSChunk(chunk), !Task.isCancelled {
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
                if let ttsRemainder = Self.validatedTTSChunk(remainder), !Task.isCancelled {
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
        // ── TTSRoutingPolicy 기반 provider 선택 (Round 256TTS-OFFICIAL-ENGINE) ──
        // Apple TTS (AVSpeechSynthesizer)는 이 switch에 없음 — 프로젝트 정책: 절대 금지.
        switch TTSRoutingPolicy.selectedProvider() {

        case .supertonic3:
            // Round 257TTS: 합성 결과를 AudioPlaybackService.playFloatSamples로 직접 재생.
            // Round 258TTS: prosody 전처리 + pitch/rate/speed 캐릭터별 적용.
            // Round 258B: emotion-aware pitch/rate/speed 적용.
            // onPlaybackStarted는 playerNode.play() 이후 AudioPlaybackService가 호출 — 립싱크 원칙 준수.
            AppLog.info("[AICall] callType=tts provider=supertonic3 (official)")
            do {
                let preset  = SupertonicVoicePresetPolicy.preset(for: agentID)
                let emotion = SupertonicVoicePresetPolicy.emotionStyle(for: agentID)
                let pitch   = SupertonicVoicePresetPolicy.pitch(for: agentID, emotion: emotion)
                let rate    = SupertonicVoicePresetPolicy.rate(for: agentID, emotion: emotion)
                let speed   = SupertonicVoicePresetPolicy.speed(for: agentID, emotion: emotion)
                // Round 266: TTS character config 로그 — agentID가 nil이면 기본 preset 사용
                AppLog.info("[TTS-CharConfig] agentID=\(agentID ?? "nil") preset=\(preset) emotion=\(emotion.rawValue) pitch=\(pitch) rate=\(rate) speed=\(speed)")
                // 텍스트 전처리 — 말풍선 원문은 건드리지 않고 TTS 입력만 처리
                let spokenText = SupertonicProsodyTextProcessor.preprocess(text, agentID: agentID, style: emotion)
                let paths = Supertonic3ONNXModelPaths.defaultPaths()
                let result = try await Supertonic3ONNXRunner.shared.synthesize(
                    text: spokenText,
                    preset: preset,
                    lang: Supertonic3TTSConfig.selectedLanguage,
                    totalSteps: Supertonic3TTSConfig.totalStep,
                    speed: speed,
                    paths: paths
                )
                // 실제 재생: playerNode.play() 이후 onPlaybackStarted 호출됨
                let didPlay = await playback.playFloatSamples(
                    samples: result.wavSamples,
                    sampleRate: result.sampleRate,
                    streamId: streamId ?? UUID().uuidString,
                    characterName: characterName,
                    pitch: pitch,
                    rate: rate,
                    onPlaybackStarted: onPlaybackStarted
                )
                if !didPlay {
                    AppLog.warning("[SpeechManager] Supertonic3 playback failed after synthesis")
                }
            } catch {
                AppLog.info("[SpeechManager] Supertonic3 synthesis failed: \(error) → silent")
                onPlaybackStarted()
            }

        case .none:
            // 무음 — provider 없음 또는 조건 미충족. Apple TTS 폴백 없음.
            AppLog.info("[AICall] callType=tts skipped (noProvider → silent)")
            onPlaybackStarted()
        }
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
        Task(priority: .userInitiated) {
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
                if let validated = Self.validatedTTSChunk(trimmed) { chunks.append(validated) }
                currentChunk = ""
            }
        }
        let finalTrimmed = currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validated = Self.validatedTTSChunk(finalTrimmed) { chunks.append(validated) }
        return chunks
    }

    nonisolated static func validatedTTSChunk(_ text: String) -> String? {
        guard text.contains(where: { $0.isTTSMeaningfulCharacter }) else {
            return nil
        }
        return text
    }

    func speak(text: String, agentID: String? = nil, characterName: String? = nil) {
        guard !AgentWindowManager.shared.isSilentMode else { return }
        abortPipelinedStream()
        let character = characterName
            ?? agentID.flatMap { id in
                AgentWindowManager.shared.allAvailableAgents.first(where: { $0.id == id })?.name
            }
            ?? "루나"
        currentSpeakingAgentID = agentID
        DispatchQueue.main.async { self.isSpeaking = true }

        currentStreamTask = Task(priority: .userInitiated) {
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
        guard TTSRoutingPolicy.selectedProvider() == .supertonic3 else { return nil }
        let preset  = SupertonicVoicePresetPolicy.preset(for: agentID)
        let emotion = SupertonicVoicePresetPolicy.emotionStyle(for: agentID)
        let pitch   = SupertonicVoicePresetPolicy.pitch(for: agentID, emotion: emotion)
        let rate    = SupertonicVoicePresetPolicy.rate(for: agentID, emotion: emotion)
        let speed   = SupertonicVoicePresetPolicy.speed(for: agentID, emotion: emotion)
        // 텍스트 전처리 — 말풍선 원문은 건드리지 않고 TTS 입력만 처리
        let spokenText = SupertonicProsodyTextProcessor.preprocess(text, agentID: agentID, style: emotion)
        let paths = Supertonic3ONNXModelPaths.defaultPaths()
        let charName: String = agentID.flatMap { id in
            AgentWindowManager.shared.allAvailableAgents.first(where: { $0.id == id })?.name
        } ?? "루나"
        do {
            let result = try await Supertonic3ONNXRunner.shared.synthesize(
                text: spokenText,
                preset: preset,
                lang: Supertonic3TTSConfig.selectedLanguage,
                totalSteps: Supertonic3TTSConfig.totalStep,
                speed: speed,
                paths: paths
            )
            // 재생 — playerNode.play() 이후 완료
            let didPlay = await playback.playFloatSamples(
                samples: result.wavSamples,
                sampleRate: result.sampleRate,
                streamId: UUID().uuidString,
                characterName: charName,
                pitch: pitch,
                rate: rate,
                onPlaybackStarted: nil
            )
            guard didPlay else {
                AppLog.warning("[SpeechManager.speakOnce] playback failed after synthesis preset=\(preset)")
                return nil
            }
            AppLog.info("[SpeechManager.speakOnce] ▶️ played preset=\(preset) frames=\(result.wavSamples.count)")
            return TTSOutput(
                audioFileURL: nil,
                duration: result.durationSec,
                sampleRate: result.sampleRate,
                providerKind: .supertonic3
            )
        } catch {
            AppLog.info("[SpeechManager.speakOnce] failed: \(error) → silent")
            return nil
        }
    }

    // MARK: - Round 258B: Raw Preset Preview (캐릭터 보정 없음)

    /// 원본 Preset 미리듣기 — 캐릭터 pitch/rate/speed 보정 없이 순수 preset 목소리 재생.
    /// TTS Lab "원본 Preset 테스트" 전용. pitch=0, rate=1로 재생.
    func previewPreset(text: String, preset: String, speed: Float = 1.05) async -> TTSOutput? {
        guard TTSRoutingPolicy.selectedProvider() == .supertonic3 else { return nil }
        let paths = Supertonic3ONNXModelPaths.defaultPaths()
        let spokenText = SupertonicProsodyTextProcessor.preprocess(text, agentID: nil, style: .neutral)
        do {
            let result = try await Supertonic3ONNXRunner.shared.synthesize(
                text: spokenText,
                preset: preset,
                lang: Supertonic3TTSConfig.selectedLanguage,
                totalSteps: Supertonic3TTSConfig.totalStep,
                speed: speed,
                paths: paths
            )
            let didPlay = await playback.playFloatSamples(
                samples: result.wavSamples,
                sampleRate: result.sampleRate,
                streamId: UUID().uuidString,
                characterName: "Preset \(preset)",
                pitch: 0,
                rate: 1,
                onPlaybackStarted: nil
            )
            guard didPlay else {
                AppLog.warning("[SpeechManager.previewPreset] playback failed after synthesis preset=\(preset)")
                return nil
            }
            let wavPath = S3WavWriter.write(samples: result.wavSamples, sampleRate: result.sampleRate, tag: "preset_\(preset)")
            AppLog.info("[SpeechManager.previewPreset] preset=\(preset) frames=\(result.wavSamples.count)")
            return TTSOutput(audioFileURL: wavPath.map { URL(fileURLWithPath: $0) },
                             duration: result.durationSec, sampleRate: result.sampleRate, providerKind: .supertonic3)
        } catch {
            AppLog.info("[SpeechManager.previewPreset] failed: \(error)")
            return nil
        }
    }

    // MARK: - Round 258B: Character Emotion Preview

    /// 감정 표현 미리듣기 — 지정 agentID 캐릭터의 특정 emotion style로 발화.
    /// TTS Lab "감정 표현 테스트" 전용.
    func previewCharacterEmotion(text: String, agentID: String, emotion: SupertonicEmotionStyle) async -> TTSOutput? {
        guard TTSRoutingPolicy.selectedProvider() == .supertonic3 else { return nil }
        let preset     = SupertonicVoicePresetPolicy.preset(for: agentID)
        let pitch      = SupertonicVoicePresetPolicy.pitch(for: agentID, emotion: emotion)
        let rate       = SupertonicVoicePresetPolicy.rate(for: agentID, emotion: emotion)
        let speed      = SupertonicVoicePresetPolicy.speed(for: agentID, emotion: emotion)
        let spokenText = SupertonicProsodyTextProcessor.preprocess(text, agentID: agentID, style: emotion)
        let paths      = Supertonic3ONNXModelPaths.defaultPaths()
        let charName   = AgentWindowManager.shared.allAvailableAgents.first(where: { $0.id == agentID })?.name ?? agentID
        do {
            let result = try await Supertonic3ONNXRunner.shared.synthesize(
                text: spokenText, preset: preset,
                lang: Supertonic3TTSConfig.selectedLanguage,
                totalSteps: Supertonic3TTSConfig.totalStep,
                speed: speed, paths: paths
            )
            let didPlay = await playback.playFloatSamples(
                samples: result.wavSamples, sampleRate: result.sampleRate,
                streamId: UUID().uuidString, characterName: charName,
                pitch: pitch, rate: rate, onPlaybackStarted: nil
            )
            guard didPlay else {
                AppLog.warning("[SpeechManager.previewCharacterEmotion] playback failed after synthesis \(charName) emotion=\(emotion.rawValue)")
                return nil
            }
            let wavPath = S3WavWriter.write(samples: result.wavSamples, sampleRate: result.sampleRate,
                                            tag: "emotion_\(charName)_\(emotion.rawValue)")
            AppLog.info("[SpeechManager.previewCharacterEmotion] \(charName) emotion=\(emotion.rawValue)")
            return TTSOutput(audioFileURL: wavPath.map { URL(fileURLWithPath: $0) },
                             duration: result.durationSec, sampleRate: result.sampleRate, providerKind: .supertonic3)
        } catch {
            AppLog.info("[SpeechManager.previewCharacterEmotion] failed: \(error)")
            return nil
        }
    }

    // MARK: - Round 259TTS: Tuning Override Preview

    /// P/R/S 임시 튜닝 적용 미리듣기.
    /// TTS Lab "임시 P/R/S 튜닝" toggle이 ON일 때 사용.
    /// - Parameters:
    ///   - text: 발화 텍스트
    ///   - preset: Supertonic3 voice preset (e.g. "F2")
    ///   - pitch: pitch override (cents). clamp은 AudioPlaybackService 내부에서 수행.
    ///   - rate: rate override 배율. clamp은 AudioPlaybackService 내부.
    ///   - speed: Supertonic3 합성 speed. clamp(0.70~2.00)은 ONNXRunner 내부.
    ///   - emotion: prosody 전처리 감정 스타일 (기본 .neutral)
    ///   - agentID: prosody 전처리 캐릭터 ID (nil = 캐릭터 보정 없음)
    ///   - label: S3WavWriter tag 접두사
    /// - Returns: TTSOutput 또는 nil(라우팅 실패/합성 오류)
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
        guard TTSRoutingPolicy.selectedProvider() == .supertonic3 else { return nil }
        let paths = Supertonic3ONNXModelPaths.defaultPaths()
        let spokenText = SupertonicProsodyTextProcessor.preprocess(text, agentID: agentID, style: emotion,
                                                                    useExpressionTags: useExpressionTags)
        do {
            let result = try await Supertonic3ONNXRunner.shared.synthesize(
                text: spokenText,
                preset: preset,
                lang: Supertonic3TTSConfig.selectedLanguage,
                totalSteps: Supertonic3TTSConfig.totalStep,
                speed: speed,
                paths: paths
            )
            let didPlay = await playback.playFloatSamples(
                samples: result.wavSamples,
                sampleRate: result.sampleRate,
                streamId: UUID().uuidString,
                characterName: label,
                pitch: pitch,
                rate: rate,
                onPlaybackStarted: nil
            )
            guard didPlay else {
                AppLog.warning("[SpeechManager.previewWithTuning] playback failed after synthesis preset=\(preset)")
                return nil
            }
            let safeLabel = label.replacingOccurrences(of: " ", with: "_")
            let wavPath = S3WavWriter.write(samples: result.wavSamples, sampleRate: result.sampleRate,
                                            tag: "tuning_\(safeLabel)")
            AppLog.info("[SpeechManager.previewWithTuning] preset=\(preset) pitch=\(pitch) rate=\(rate) speed=\(speed) tags=\(useExpressionTags)")
            return TTSOutput(audioFileURL: wavPath.map { URL(fileURLWithPath: $0) },
                             duration: result.durationSec, sampleRate: result.sampleRate, providerKind: .supertonic3)
        } catch {
            AppLog.info("[SpeechManager.previewWithTuning] failed: \(error)")
            return nil
        }
    }

    // MARK: - Round 261TTS: Speed Probe

    /// Supertonic3 speed 적용 계측. 재생 없음. WAV 저장 없음.
    /// 기대: speed가 높을수록 durationSec이 짧아야 함.
    /// - Parameters:
    ///   - text: 계측용 텍스트
    ///   - preset: voice preset (e.g. "F1")
    /// - Returns: testSpeeds 순서의 결과 배열. 모델 없으면 빈 배열.
    func probeSpeedApplication(
        text: String,
        preset: String
    ) async -> [SupertonicSpeedProbeResult] {
        let paths = Supertonic3ONNXModelPaths.defaultPaths()
        var results: [SupertonicSpeedProbeResult] = []

        for speed in SupertonicSpeedProbe.testSpeeds {
            let t0 = CFAbsoluteTimeGetCurrent()
            do {
                let result = try await Supertonic3ONNXRunner.shared.synthesize(
                    text: text,
                    preset: preset,
                    lang: Supertonic3TTSConfig.selectedLanguage,
                    totalSteps: Supertonic3TTSConfig.totalStep,
                    speed: speed,
                    paths: paths
                )
                let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
                let entry = SupertonicSpeedProbeResult(
                    preset: preset,
                    speed: speed,
                    text: text,
                    durationSec: result.durationSec,
                    sampleRate: result.sampleRate,
                    sampleCount: result.wavSamples.count,
                    elapsedMs: elapsed,
                    realtimeFactor: result.realtimeFactor
                )
                AppLog.info("[SpeedProbe] speed=\(speed) duration=\(String(format: "%.3f", result.durationSec))s samples=\(result.wavSamples.count) rtf=\(String(format: "%.2f", result.realtimeFactor))")
                results.append(entry)
            } catch {
                AppLog.info("[SpeedProbe] speed=\(speed) failed: \(error)")
            }
        }

        let verdict = SupertonicSpeedProbe.verdictSummary(results)
        AppLog.info("[SpeedProbe] verdict: \(verdict)")
        return results
    }

    // MARK: - BubbleSpeech Effect Preview

    /// BubbleSpeech는 별도 TTS 모델이 아니라 Supertonic3 캐릭터 목소리 기반 뽀글뽀글 말하기 효과 레이어다.
    /// MyTeam의 메인 TTS 엔진은 Supertonic3이며, 이 함수는 Lab/효과 확인에만 사용한다.
    /// 반환값은 효과 재생 시간이며, Supertonic3 합성 성공으로 취급하면 안 된다.
    func previewBubbleSpeech(
        text: String,
        preset: String,
        profile: BubbleSpeechVoiceProfile,
        pitch: Float,
        rate: Float,
        speed: Float,
        emotion: SupertonicEmotionStyle = .neutral,
        agentID: String? = nil,
        pitchOffset: Float = 0,
        label: String = "bubbleSpeech",
        useExpressionTags: Bool = false
    ) async -> BubbleSpeechPreviewResult {
        guard TTSRoutingPolicy.selectedProvider() == .supertonic3 else {
            return .failed("Supertonic3 캐릭터 목소리 합성 조건이 아직 충족되지 않았습니다.")
        }

        let bubbleTuning = SupertonicVoicePresetPolicy.bubbleSpeechTuning(for: agentID)
        let basePitch = SupertonicVoicePresetPolicy.pitch(for: agentID)
        let emotionPitch = SupertonicVoicePresetPolicy.pitch(for: agentID, emotion: emotion)
        let baseRate = SupertonicVoicePresetPolicy.rate(for: agentID)
        let emotionRate = SupertonicVoicePresetPolicy.rate(for: agentID, emotion: emotion)
        let baseSpeed = SupertonicVoicePresetPolicy.speed(for: agentID)
        let emotionSpeed = SupertonicVoicePresetPolicy.speed(for: agentID, emotion: emotion)
        let playbackPitch = pitch + pitchOffset + (emotionPitch - basePitch)
        let segmentRate = min(1.08, max(0.90, rate + (emotionRate - baseRate)))
        let playbackRate = min(1.10, max(0.90, segmentRate))
        let speedWithEmotion = speed + (emotionSpeed - baseSpeed)
        let synthesisSpeed = min(1.42, max(1.06, max(speedWithEmotion, bubbleTuning.speed)))
        var config = BubbleSpeechConfig.from(profile: profile, speed: Double(synthesisSpeed))
        config.characterTuning = BubbleSpeechCharacterTuningPolicy.tuning(
            agentID: agentID,
            preset: preset,
            profile: profile
        )
        let paths = Supertonic3ONNXModelPaths.defaultPaths()
        let spokenText = SupertonicProsodyTextProcessor.preprocess(
            text,
            agentID: agentID,
            style: emotion,
            useExpressionTags: useExpressionTags
        )

        let result: Supertonic3SynthesisResult
        do {
            result = try await Supertonic3ONNXRunner.shared.synthesize(
                text: spokenText,
                preset: preset,
                lang: Supertonic3TTSConfig.selectedLanguage,
                totalSteps: Supertonic3TTSConfig.totalStep,
                speed: synthesisSpeed,
                paths: paths
            )
        } catch {
            AppLog.info("[BubbleSpeechEffect] Supertonic3 voice synthesis failed: \(error)")
            return .failed("Supertonic3 캐릭터 목소리 합성이 완료되지 않았습니다.")
        }

        let samples = BubbleSpeechSynthesizer.renderVoiceBasedEffect(
            text: spokenText,
            voiceSamples: result.wavSamples,
            sampleRate: result.sampleRate,
            config: config,
            segmentRate: segmentRate
        )
        guard !samples.isEmpty else {
            AppLog.warning("[BubbleSpeechEffect] failed: empty rendered samples voiceBased=true preset=\(preset) agentID=\(agentID ?? "nil") profile=\(profile.rawValue) synthesisSpeed=\(synthesisSpeed) segmentRate=\(segmentRate) playbackPitch=\(playbackPitch) emotion=\(emotion.rawValue) inputChars=\(spokenText.count) syllableCount=\(BubbleSpeechSynthesizer.syllableCount(in: spokenText)) sourceSamples=\(result.wavSamples.count)")
            return .failed("뽀글뽀글 음절 리듬 렌더링이 완료되지 않았습니다.")
        }

        let sampleRate = result.sampleRate
        let durationSec = Double(samples.count) / Double(sampleRate)
        let snapshot = AudioFeatureAnalyzer.analyze(samples: samples, sampleRate: sampleRate)
        let delta = BubbleSpeechSynthesizer.meanAbsoluteDelta(samples, result.wavSamples)
        let durationRatio = BubbleSpeechSynthesizer.durationRatio(renderedSamples: samples, sourceSamples: result.wavSamples)
        let syllableCount = BubbleSpeechSynthesizer.syllableCount(in: spokenText)
        let isFinite = !samples.contains { !$0.isFinite }
        guard durationRatio > 0.18,
              durationRatio < 0.95,
              delta > 0.002,
              snapshot.peak > 0.01,
              isFinite else {
            AppLog.warning("[BubbleSpeechEffect] failed: invalid output metrics preset=\(preset) agentID=\(agentID ?? "nil") profile=\(profile.rawValue) durationRatio=\(String(format: "%.3f", durationRatio)) peak=\(String(format: "%.3f", snapshot.peak)) meanDelta=\(String(format: "%.5f", delta)) isFinite=\(isFinite)")
            return .failed("뽀글뽀글 렌더링 품질 기준을 통과하지 못했습니다.")
        }

        let didPlay = await playback.playFloatSamples(
            samples: samples,
            sampleRate: sampleRate,
            streamId: UUID().uuidString,
            characterName: label,
            pitch: playbackPitch,
            rate: playbackRate,
            onPlaybackStarted: nil
        )
        guard didPlay else {
            AppLog.warning("[BubbleSpeechEffect] playback failed after render")
            return .failed("출력 장치 또는 오디오 엔진 재생 실패로 뽀글뽀글 말하기를 재생하지 못했습니다.")
        }

        let safeAgent = (agentID ?? "none").replacingOccurrences(of: " ", with: "_")
        let safeLabel = label.replacingOccurrences(of: " ", with: "_")
        let safePitch = String(format: "%.0f", playbackPitch)
        let safeRate = String(format: "%.2f", segmentRate).replacingOccurrences(of: ".", with: "p")
        let safeSpeed = String(format: "%.2f", synthesisSpeed).replacingOccurrences(of: ".", with: "p")
        let wavTag = "bubble_speech_\(safeLabel)_\(safeAgent)_\(preset)_\(profile.rawValue)_p\(safePitch)_r\(safeRate)_syn\(safeSpeed)"
        _ = S3WavWriter.write(samples: samples, sampleRate: sampleRate, tag: wavTag)
        AppLog.info("[BubbleSpeechEffect] voiceBased=true mode=singlePassChopper preset=\(preset) agentID=\(agentID ?? "nil") profile=\(profile.rawValue) kind=\(profile.profileKindLabel) emotion=\(emotion.rawValue) synthesisSpeed=\(synthesisSpeed) segmentRate=\(segmentRate) playbackRate=\(playbackRate) playbackPitch=\(playbackPitch) minSegment=\(String(format: "%.3f", config.characterTuning.minSegmentDuration)) maxSegment=\(String(format: "%.3f", config.characterTuning.maxSegmentDuration)) guideGain=\(String(format: "%.3f", config.characterTuning.guideGain)) shimmerDepth=\(String(format: "%.3f", config.characterTuning.shimmerDepth)) gapScale=\(String(format: "%.2f", config.characterTuning.gapScale)) inputChars=\(spokenText.count) syllableCount=\(syllableCount) sourceSamples=\(result.wavSamples.count) renderedSamples=\(samples.count) duration=\(String(format: "%.3f", durationSec))s durationRatio=\(String(format: "%.3f", durationRatio)) peak=\(String(format: "%.3f", snapshot.peak)) zcr=\(String(format: "%.1f", snapshot.zeroCrossingRate)) clicks=\(snapshot.estimatedClickCount) meanDelta=\(String(format: "%.5f", delta)) wavTag=\(wavTag)")
        return .played(duration: durationSec)
    }

    /// 단발성 공식 TTS 합성. 반환값: WAV 파일 경로 (nil=무음 또는 실패).
    /// 호출 시점에만 Supertonic3ONNXRunner.shared.synthesize 실행. launch auto-init 없음.
    func synthesize(text: String, agentID: String? = nil) async -> TTSOutput? {
        guard TTSRoutingPolicy.selectedProvider() == .supertonic3 else { return nil }
        let preset = SupertonicVoicePresetPolicy.preset(for: agentID)
        let paths = Supertonic3ONNXModelPaths.defaultPaths()
        do {
            let result = try await Supertonic3ONNXRunner.shared.synthesize(
                text: text,
                preset: preset,
                lang: Supertonic3TTSConfig.selectedLanguage,
                totalSteps: Supertonic3TTSConfig.totalStep,
                paths: paths
            )
            guard let wavPath = S3WavWriter.write(
                samples: result.wavSamples,
                sampleRate: result.sampleRate,
                tag: "manual_\(preset)"
            ) else { return nil }
            return TTSOutput(
                audioFileURL: URL(fileURLWithPath: wavPath),
                duration: result.durationSec,
                sampleRate: result.sampleRate,
                providerKind: .supertonic3
            )
        } catch {
            AppLog.info("[SpeechManager.synthesize] failed: \(error)")
            return nil
        }
    }

    // MARK: - Barge-in 격추 시스템
    func abortPipelinedStream() {
        currentStreamTask?.cancel()
        currentStreamTask = nil

        // 오디오 엔진 즉각 정지
        Task(priority: .userInitiated) { await playback.stopAll() }

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

struct BubbleSpeechPreviewResult: Sendable {
    let duration: TimeInterval
    let failureMessage: String?

    static func played(duration: TimeInterval) -> BubbleSpeechPreviewResult {
        BubbleSpeechPreviewResult(duration: duration, failureMessage: nil)
    }

    static func failed(_ message: String) -> BubbleSpeechPreviewResult {
        BubbleSpeechPreviewResult(duration: 0, failureMessage: message)
    }

    var didPlay: Bool {
        failureMessage == nil && duration > 0
    }
}

struct PreparedTerminationFarewell: Sendable {
    let agentID: String
    let characterName: String
    let text: String
    let samples: [Float]
    let sampleRate: Int
    let pitch: Float
    let rate: Float
}

struct TerminationFarewellRequest: Sendable {
    let agentID: String
    let characterName: String
    let text: String
    let spokenText: String
    let preset: String
    let speed: Float
    let pitch: Float
    let rate: Float
}

@MainActor
final class AppTerminationSpeechService {
    static let shared = AppTerminationSpeechService()

    private var preparedFarewell: PreparedTerminationFarewell?
    private var prepareTask: Task<Void, Never>?
    private var isTerminationPlaybackPending = false

    private init() {}

    func scheduleInitialPrewarm(manager: AgentWindowManager) {
        prepareTask?.cancel()
        prepareTask = Task(priority: .utility) { [weak self, weak manager] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled, let self, let manager else { return }
            self.refreshForCurrentTeamLeader(manager: manager)
        }
    }

    func refreshForCurrentTeamLeader(manager: AgentWindowManager) {
        guard manager.isVoiceMode else {
            preparedFarewell = nil
            return
        }
        guard !manager.isSilentMode else {
            preparedFarewell = nil
            return
        }
        guard TTSRoutingPolicy.selectedProvider() == .supertonic3 else {
            preparedFarewell = nil
            return
        }
        guard let leader = manager.fallbackTeamLeader(for: manager.selectedTeamWorkroomID),
              let line = CharacterDialogues.leaderLine(for: leader.id, event: .appWillQuit) else {
            preparedFarewell = nil
            return
        }

        prepareTask?.cancel()
        let emotion = SupertonicVoicePresetPolicy.emotionStyle(for: leader.id)
        let request = TerminationFarewellRequest(
            agentID: leader.id,
            characterName: leader.name,
            text: line.text,
            spokenText: SupertonicProsodyTextProcessor.preprocess(line.text, agentID: leader.id, style: emotion),
            preset: SupertonicVoicePresetPolicy.preset(for: leader.id),
            speed: SupertonicVoicePresetPolicy.speed(for: leader.id, emotion: emotion),
            pitch: SupertonicVoicePresetPolicy.pitch(for: leader.id, emotion: emotion),
            rate: SupertonicVoicePresetPolicy.rate(for: leader.id, emotion: emotion)
        )

        prepareTask = Task(priority: .utility) { [weak self] in
            let prepared = await AppTerminationSpeechService.synthesizePreparedFarewell(request)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.preparedFarewell = prepared
                if let prepared {
                    AppLog.info("[AppTerminationSpeech] prepared farewell agentID=\(prepared.agentID) frames=\(prepared.samples.count)")
                }
            }
        }
    }

    func playPreparedFarewell(completion: @MainActor @escaping @Sendable () -> Void) -> Bool {
        guard !isTerminationPlaybackPending else { return true }
        guard AgentWindowManager.shared.isVoiceMode, !AgentWindowManager.shared.isSilentMode else { return false }
        guard let prepared = preparedFarewell, !prepared.samples.isEmpty else { return false }
        guard prepared.agentID == currentTeamLeaderAgentID() else {
            AppLog.info("[AppTerminationSpeech] prepared farewell skipped: team leader changed")
            return false
        }

        isTerminationPlaybackPending = true
        Task(priority: .userInitiated) {
            let didPlay = await AudioPlaybackService.shared.playFloatSamples(
                samples: prepared.samples,
                sampleRate: prepared.sampleRate,
                streamId: "termination-\(UUID().uuidString)",
                characterName: prepared.characterName,
                pitch: prepared.pitch,
                rate: prepared.rate,
                onPlaybackStarted: nil
            )
            if !didPlay {
                await MainActor.run {
                    AppLog.warning("[AppTerminationSpeech] prepared farewell playback failed")
                    self.finishTermination(completion: completion)
                }
            }
        }

        Task(priority: .userInitiated) { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.finishTermination(completion: completion)
        }
        return true
    }

    private func currentTeamLeaderAgentID() -> String? {
        let manager = AgentWindowManager.shared
        return manager.fallbackTeamLeader(for: manager.selectedTeamWorkroomID)?.id
    }

    private func finishTermination(completion: @MainActor @escaping @Sendable () -> Void) {
        guard isTerminationPlaybackPending else { return }
        isTerminationPlaybackPending = false
        completion()
    }

    nonisolated private static func synthesizePreparedFarewell(_ request: TerminationFarewellRequest) async -> PreparedTerminationFarewell? {
        do {
            let result = try await Supertonic3ONNXRunner.shared.synthesize(
                text: request.spokenText,
                preset: request.preset,
                lang: Supertonic3TTSConfig.selectedLanguage,
                totalSteps: Supertonic3TTSConfig.totalStep,
                speed: request.speed,
                paths: Supertonic3ONNXModelPaths.defaultPaths()
            )
            guard !result.wavSamples.isEmpty else {
                AppLog.warning("[AppTerminationSpeech] prepared synthesis returned empty samples")
                return nil
            }
            return PreparedTerminationFarewell(
                agentID: request.agentID,
                characterName: request.characterName,
                text: request.text,
                samples: result.wavSamples,
                sampleRate: result.sampleRate,
                pitch: request.pitch,
                rate: request.rate
            )
        } catch {
            AppLog.warning("[AppTerminationSpeech] farewell prewarm failed: \(error)")
            return nil
        }
    }
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
