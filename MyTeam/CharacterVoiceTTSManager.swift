import AVFoundation
import Foundation

// ============================================================
// CharacterVoiceTTSManager.swift
// 캐릭터별 고품질 음소 폴더 기반 Animal Crossing TTS
//
// AnimalTTSManager의 개선판:
//   - 5가지 목소리 유형별 폴더에서 음소 WAV 로드
//   - 한/영/일 3개 언어 자동 감지 후 해당 음소 사용
//   - ElevenLabs로 생성한 고품질 WAV 파일 활용
//
// 폴더 구조 (Resources/Phonemes/ 하위):
//   bright_female/ko/아.wav, bright_female/en/a.wav, bright_female/ja/a.wav ...
//   deep_male/ko/...
//   neutral_male/ko/...
//   energetic_female/ko/...
//   casual_male/ko/...
//   (폴더 없으면 기존 AnimalTTSManager로 자동 폴백)
//
// 캐릭터 → 목소리 유형 매핑:
//   bright_female:    치코, 루나, 몽몽
//   deep_male:        레오, 렉스, 올리버
//   neutral_male:     케이, 모코
//   energetic_female: 핀, 폴라
//   casual_male:      래키
// ============================================================

class CharacterVoiceTTSManager: NSObject {
    static let shared = CharacterVoiceTTSManager()

    // MARK: - 캐릭터 → 목소리 유형 매핑
    static let characterVoiceType: [String: String] = [
        "치코":   "bright_female",
        "루나":   "bright_female",
        "몽몽":   "bright_female",
        "레오":   "deep_male",
        "렉스":   "deep_male",
        "올리버": "deep_male",
        "케이":   "neutral_male",
        "모코":   "neutral_male",
        "핀":     "energetic_female",
        "폴라":   "energetic_female",
        "래키":   "casual_male",
    ]

    // MARK: - 목소리 유형별 피치/속도 프로필
    // 목소리 파일이 이미 특성을 가지므로 pitch를 더 보수적으로 적용
    struct VoiceTypeProfile {
        let pitch: Float       // 세미톤 cents 조정 (±)
        let pitchJitter: Float
        let interval: Double
        let volume: Float
    }

    static let voiceTypeProfiles: [String: VoiceTypeProfile] = [
        "bright_female":    VoiceTypeProfile(pitch: 200,  pitchJitter: 80,  interval: 0.055, volume: 0.88),
        "deep_male":        VoiceTypeProfile(pitch: -200, pitchJitter: 30,  interval: 0.095, volume: 0.90),
        "neutral_male":     VoiceTypeProfile(pitch: -100, pitchJitter: 20,  interval: 0.080, volume: 0.85),
        "energetic_female": VoiceTypeProfile(pitch: 300,  pitchJitter: 100, interval: 0.050, volume: 0.87),
        "casual_male":      VoiceTypeProfile(pitch: -50,  pitchJitter: 80,  interval: 0.070, volume: 0.84),
    ]

    // MARK: - 오디오 엔진 (캐릭터별 독립 캐시)
    private let audioEngine = AVAudioEngine()
    private let playerNode  = AVAudioPlayerNode()
    private let pitchNode   = AVAudioUnitTimePitch()
    private let reverbNode  = AVAudioUnitReverb()
    private var engineFormat: AVAudioFormat!

    // voiceType → language → phonemeKey → Buffer
    private var phonemeCache: [String: [String: [String: AVAudioPCMBuffer]]] = [:]
    private(set) var isReady: Bool = false

    private var isSpeaking = false
    private var speakTask: Task<Void, Never>? = nil

    // MARK: - 초기화
    private override init() {
        super.init()
        setupAudioEngine()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadAllPhonemes()
        }
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        audioEngine.attach(reverbNode)
        engineFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: pitchNode,   format: engineFormat)
        audioEngine.connect(pitchNode,  to: reverbNode,  format: engineFormat)
        audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format: engineFormat)
        reverbNode.loadFactoryPreset(.smallRoom)
        reverbNode.wetDryMix = 12
        try? audioEngine.start()
    }

    // MARK: - 음소 파일 로드
    private func loadAllPhonemes() {
        guard let resourceDir = Bundle.main.resourceURL else { return }
        let phonemesBase = resourceDir.appendingPathComponent("Phonemes")
        let voiceTypes = ["bright_female", "deep_male", "neutral_male", "energetic_female", "casual_male"]
        let languages  = ["ko", "en", "ja"]

        var totalLoaded = 0
        for voiceType in voiceTypes {
            phonemeCache[voiceType] = [:]
            for lang in languages {
                let langDir = phonemesBase.appendingPathComponent(voiceType).appendingPathComponent(lang)
                guard FileManager.default.fileExists(atPath: langDir.path) else { continue }

                phonemeCache[voiceType]![lang] = [:]
                if let files = try? FileManager.default.contentsOfDirectory(at: langDir, includingPropertiesForKeys: nil)
                    .filter({ $0.pathExtension == "wav" || $0.pathExtension == "mp3" }) {
                    for file in files {
                        let key = file.deletingPathExtension().lastPathComponent
                        if let buffer = loadAndConvertAudio(url: file) {
                            phonemeCache[voiceType]![lang]![key] = buffer
                            totalLoaded += 1
                        }
                    }
                }
            }
        }

        isReady = totalLoaded > 0
        print("[CharacterVoiceTTS] ✅ \(totalLoaded)개 음소 로드 완료 (isReady: \(isReady))")
    }

    private func loadAndConvertAudio(url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let srcFormat = file.processingFormat
        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: srcBuffer)) != nil else { return nil }

        if srcFormat.sampleRate == engineFormat.sampleRate && srcFormat.channelCount == engineFormat.channelCount {
            return srcBuffer
        }
        guard let converter = AVAudioConverter(from: srcFormat, to: engineFormat) else { return nil }
        let ratio = engineFormat.sampleRate / srcFormat.sampleRate
        let outFrames = AVAudioFrameCount(Double(srcBuffer.frameLength) * ratio) + 100
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: engineFormat, frameCapacity: outFrames) else { return nil }
        var inputConsumed = false
        converter.convert(to: outBuffer, error: nil) { _, outStatus in
            if !inputConsumed {
                inputConsumed = true
                outStatus.pointee = .haveData
                return srcBuffer
            }
            outStatus.pointee = .endOfStream
            return nil
        }
        return outBuffer
    }

    // MARK: - 언어 감지
    private func detectLanguage(_ text: String) -> String {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // 한글 범위: AC00–D7A3 (완성형), 1100–11FF (자모)
            if (v >= 0xAC00 && v <= 0xD7A3) || (v >= 0x1100 && v <= 0x11FF) { return "ko" }
            // 일본어 범위: 3040–309F (히라가나), 30A0–30FF (가타카나), 4E00–9FFF (한자 공통)
            if (v >= 0x3040 && v <= 0x30FF) { return "ja" }
        }
        return "en"
    }

    // MARK: - 음소 분해 (언어별)
    private func decomposeText(_ text: String, language: String) -> [String] {
        switch language {
        case "ko": return HangulDecomposer.decompose(text).filter { $0 != "pause" }
        case "ja": return KanaDecomposer.decompose(text)
        default:   return EnglishPhonemeDecomposer.decompose(text)
        }
    }

    // MARK: - 공개 API

    /// 캐릭터 이름으로 Animal Crossing 스타일 재생
    func speak(_ text: String, characterName: String) {
        guard isReady else {
            print("[CharacterVoiceTTS] 아직 로딩 중")
            return
        }
        stop()

        let voiceType = CharacterVoiceTTSManager.characterVoiceType[characterName] ?? "neutral_male"
        guard let langMap = phonemeCache[voiceType], !langMap.isEmpty else {
            print("[CharacterVoiceTTS] '\(voiceType)' 음소 없음 → AnimalTTS 폴백")
            AnimalTTSManager.shared.speak(text, voice: .character(characterName))
            return
        }

        let lang = detectLanguage(text)
        // 해당 언어 파일 없으면 ko 폴백
        let phonemeMap = langMap[lang] ?? langMap["ko"] ?? [:]
        let phonemes = decomposeText(text, language: lang)
        guard !phonemes.isEmpty else { return }

        let profile = CharacterVoiceTTSManager.voiceTypeProfiles[voiceType]
            ?? VoiceTypeProfile(pitch: 0, pitchJitter: 50, interval: 0.08, volume: 0.85)

        isSpeaking = true
        speakTask = Task { [weak self] in
            guard let self = self else { return }
            if !self.audioEngine.isRunning { try? self.audioEngine.start() }

            for key in phonemes {
                guard self.isSpeaking else { break }
                let buffer = phonemeMap[key] ?? phonemeMap[self.fallbackKey(for: key, lang: lang)]
                if let buffer = buffer {
                    let jitter = Float.random(in: -profile.pitchJitter...profile.pitchJitter)
                    self.pitchNode.pitch = profile.pitch + jitter
                    self.playerNode.volume = profile.volume
                    self.playerNode.stop()
                    await self.playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
                    self.playerNode.play()
                }
                let delay = UInt64(profile.interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            self.isSpeaking = false
        }
    }

    func stop() {
        isSpeaking = false
        speakTask?.cancel()
        speakTask = nil
        playerNode.stop()
    }

    private func fallbackKey(for key: String, lang: String) -> String {
        if lang == "ko" {
            let vowels = ["ae","ya","yae","eo","yeo","ye","wa","wae","oe","yo","wo","we","wi","yu","eu","ui","a","e","i","o","u"]
            for v in vowels { if key.hasSuffix(v) { return v } }
            return "a"
        }
        return String(key.prefix(1))
    }
}

// MARK: - 영어 음소 분해 (간이)
enum EnglishPhonemeDecomposer {
    static func decompose(_ text: String) -> [String] {
        // 각 음절을 소문자 2자 이내로 분해 (자음+모음 조합)
        let vowels: Set<Character> = ["a","e","i","o","u"]
        var result: [String] = []
        var prev: Character? = nil
        for ch in text.lowercased() {
            guard ch.isLetter else { prev = nil; continue }
            if vowels.contains(ch) {
                if let p = prev {
                    result.append("\(p)\(ch)")
                } else {
                    result.append(String(ch))
                }
                prev = nil
            } else {
                prev = ch
            }
        }
        return result.isEmpty ? ["a"] : result
    }
}
