import AVFoundation
import Foundation

// ============================================================
// AnimalTTSManager.swift
// 동물의 숲 스타일 TTS 엔진
//
// 동작 방식:
//   1. 텍스트를 음소(phoneme) 키로 분해 (HangulDecomposer)
//   2. 각 음소에 해당하는 WAV 파일을 번들에서 로드
//   3. AVAudioEngine으로 피치 조절 + 약한 리버브 적용
//   4. 음소를 빠르게 순서대로 재생 → Animal Crossing 느낌
//
// 사용법:
//   AnimalTTSManager.shared.speak("안녕하세요!", voice: .sloth)
//   AnimalTTSManager.shared.stop()
// ============================================================

class AnimalTTSManager: NSObject {

    static let shared = AnimalTTSManager()

    // MARK: - 캐릭터별 목소리 설정
    struct VoiceProfile {
        let pitch: Float        // 피치 배율 (0.5 낮음 ~ 2.0 높음, 기본 1.0)
        let pitchJitter: Float  // 음소마다 랜덤으로 흔들리는 피치 범위
        let interval: Double    // 음소 간격 (초) — 짧을수록 빠름
        let volume: Float       // 볼륨 (0.0 ~ 1.0)
    }

    enum Voice {
        case sloth      // 슬로스: 낮고 느릿한 목소리
        case dog        // 개: 높고 활발한 목소리
        case `default`  // 기본

        var profile: VoiceProfile {
            switch self {
            case .sloth:
                return VoiceProfile(pitch: 0.80, pitchJitter: 0.04, interval: 0.16, volume: 0.85)
            case .dog:
                return VoiceProfile(pitch: 1.35, pitchJitter: 0.12, interval: 0.09, volume: 0.90)
            case .default:
                return VoiceProfile(pitch: 1.00, pitchJitter: 0.08, interval: 0.11, volume: 0.80)
            }
        }
    }

    // MARK: - 내부 상태
    private let audioEngine = AVAudioEngine()
    private let playerNode  = AVAudioPlayerNode()
    private let pitchNode   = AVAudioUnitTimePitch()
    private let reverbNode  = AVAudioUnitReverb()

    // 음소 WAV 버퍼 캐시 (메모리 상주, 앱 실행 중 유지)
    private var phonemeCache: [String: AVAudioPCMBuffer] = [:]

    // 재생 취소용
    private var isSpeaking = false
    private var speakTask: Task<Void, Never>? = nil

    // MARK: - 초기화
    private override init() {
        super.init()
        setupAudioEngine()
        loadPhonemeCache()
    }

    // MARK: - 오디오 엔진 구성
    // playerNode → pitchNode → reverbNode → mainMixer → output
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        audioEngine.attach(reverbNode)

        let format = audioEngine.outputNode.outputFormat(forBus: 0)

        audioEngine.connect(playerNode,  to: pitchNode,   format: format)
        audioEngine.connect(pitchNode,   to: reverbNode,  format: format)
        audioEngine.connect(reverbNode,  to: audioEngine.mainMixerNode, format: format)

        // 약한 리버브 → 동물의 숲 특유의 "공간감"
        reverbNode.loadFactoryPreset(.smallRoom)
        reverbNode.wetDryMix = 15  // 0 = dry, 100 = full reverb

        do {
            try audioEngine.start()
        } catch {
            print("[AnimalTTS] 오디오 엔진 시작 실패: \(error)")
        }
    }

    // MARK: - 음소 WAV 파일을 번들에서 로드
    private func loadPhonemeCache() {
        // Resources/Phonemes/*.wav 파일을 모두 로드
        guard let phonemeDir = Bundle.main.resourceURL?
            .appendingPathComponent("Phonemes") else {
            print("[AnimalTTS] ⚠️  Phonemes 폴더가 번들에 없습니다. Xcode에 추가해주세요.")
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: phonemeDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "wav" }

            var loadedCount = 0
            for url in files {
                let key = url.deletingPathExtension().lastPathComponent
                if let buffer = loadWAV(url: url) {
                    phonemeCache[key] = buffer
                    loadedCount += 1
                }
            }
            print("[AnimalTTS] ✅ \(loadedCount)개 음소 로드 완료")
        } catch {
            print("[AnimalTTS] 음소 파일 로드 실패: \(error)")
        }
    }

    private func loadWAV(url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            print("[AnimalTTS] WAV 로드 실패 \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - 공개 API

    /// 텍스트를 Animal Crossing 스타일로 재생합니다.
    /// - Parameters:
    ///   - text: 재생할 텍스트
    ///   - voice: 캐릭터 목소리 (기본값: .default)
    func speak(_ text: String, voice: Voice = .default) {
        stop()  // 이전 재생 중단

        let profile = voice.profile
        let phonemes = HangulDecomposer.decompose(text)
            .filter { $0 != "pause" }  // 공백은 타이밍으로만 처리

        isSpeaking = true

        speakTask = Task { [weak self] in
            guard let self = self else { return }

            for key in phonemes {
                guard self.isSpeaking else { break }

                // 음소 버퍼 조회 (조합키 없으면 모음만)
                let buffer = self.phonemeCache[key]
                    ?? self.phonemeCache[self.fallbackKey(for: key)]

                if let buffer = buffer {
                    // 음소마다 피치를 약간씩 랜덤으로 흔들기 → 생동감
                    let jitter = Float.random(in: -profile.pitchJitter...profile.pitchJitter)
                    let semitones = (profile.pitch - 1.0) * 12.0 + jitter * 12.0
                    self.pitchNode.pitch = semitones * 100  // cents 단위
                    self.playerNode.volume = profile.volume
                    self.playerNode.scheduleBuffer(buffer, completionCallbackType: .dataConsumed) { _ in }  // async-safe API
                    self.playerNode.play()
                }

                // 다음 음소까지 대기
                let delay = UInt64(profile.interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }

            self.isSpeaking = false
        }
    }

    /// 재생 중인 TTS를 즉시 중단합니다.
    func stop() {
        isSpeaking = false
        speakTask?.cancel()
        speakTask = nil
        playerNode.stop()
    }

    // 조합 키가 없을 때 모음 부분만 추출
    // 예: "na" → "a", "mi" → "i", "cha" → "a"
    private func fallbackKey(for key: String) -> String {
        let vowelSuffixes = ["ae", "ya", "yae", "eo", "yeo", "ye", "wa", "wae",
                             "oe", "yo", "wo", "we", "wi", "yu", "eu", "ui",
                             "a", "e", "i", "o", "u"]
        for vowel in vowelSuffixes {
            if key.hasSuffix(vowel) {
                return vowel
            }
        }
        return "a"  // 최후 fallback
    }
}
