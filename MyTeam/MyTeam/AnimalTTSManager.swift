import AVFoundation
import Foundation

// ============================================================
// AnimalTTSManager.swift
// 동물의 숲 스타일 TTS 엔진
//
// 동작 방식:
//   1. 텍스트를 음소(phoneme) 키로 분해 (HangulDecomposer)
//   2. 각 음소에 해당하는 WAV 파일을 번들에서 로드 → 엔진 포맷으로 변환
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

    // 엔진 공통 포맷 (44100Hz 스테레오) — 모든 WAV를 이 포맷으로 변환
    private var engineFormat: AVAudioFormat!

    // 음소 WAV 버퍼 캐시 (엔진 포맷으로 변환된 상태)
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

        // 엔진의 메인 믹서 출력 포맷 사용 (보통 44100Hz 스테레오)
        engineFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        print("[AnimalTTS] 엔진 포맷: \(engineFormat!)")

        // 모든 노드를 동일한 포맷으로 연결 (포맷 불일치 방지)
        audioEngine.connect(playerNode,  to: pitchNode,   format: engineFormat)
        audioEngine.connect(pitchNode,   to: reverbNode,  format: engineFormat)
        audioEngine.connect(reverbNode,  to: audioEngine.mainMixerNode, format: engineFormat)

        // 약한 리버브 → 동물의 숲 특유의 "공간감"
        reverbNode.loadFactoryPreset(.smallRoom)
        reverbNode.wetDryMix = 15  // 0 = dry, 100 = full reverb

        do {
            try audioEngine.start()
            print("[AnimalTTS] ✅ 오디오 엔진 시작 성공")
        } catch {
            print("[AnimalTTS] ❌ 오디오 엔진 시작 실패: \(error)")
        }
    }

    // MARK: - 음소 WAV 파일을 번들에서 로드 + 포맷 변환
    private func loadPhonemeCache() {
        guard let resourceDir = Bundle.main.resourceURL else {
            print("[AnimalTTS] ⚠️  번들 리소스 경로를 찾을 수 없습니다.")
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: resourceDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "wav" }

            var loadedCount = 0
            for url in files {
                let key = url.deletingPathExtension().lastPathComponent
                if let buffer = loadAndConvertWAV(url: url) {
                    phonemeCache[key] = buffer
                    loadedCount += 1
                }
            }
            print("[AnimalTTS] ✅ \(loadedCount)개 음소 로드 + 포맷 변환 완료")
        } catch {
            print("[AnimalTTS] ❌ 음소 파일 로드 실패: \(error)")
        }
    }

    /// WAV 파일을 읽어서 엔진 포맷(44100Hz 스테레오)으로 변환
    private func loadAndConvertWAV(url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            let srcFormat = file.processingFormat

            // 원본 버퍼 읽기
            guard let srcBuffer = AVAudioPCMBuffer(
                pcmFormat: srcFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return nil }
            try file.read(into: srcBuffer)

            // 포맷이 이미 같으면 그대로 반환
            if srcFormat.sampleRate == engineFormat.sampleRate &&
               srcFormat.channelCount == engineFormat.channelCount {
                return srcBuffer
            }

            // 포맷 변환 (16kHz mono → 44100Hz stereo 등)
            guard let converter = AVAudioConverter(from: srcFormat, to: engineFormat) else {
                print("[AnimalTTS] 컨버터 생성 실패: \(url.lastPathComponent)")
                return nil
            }

            let ratio = engineFormat.sampleRate / srcFormat.sampleRate
            let outFrames = AVAudioFrameCount(Double(srcBuffer.frameLength) * ratio) + 100
            guard let outBuffer = AVAudioPCMBuffer(
                pcmFormat: engineFormat,
                frameCapacity: outFrames
            ) else { return nil }

            var error: NSError?
            var inputConsumed = false

            converter.convert(to: outBuffer, error: &error) { _, outStatus in
                if !inputConsumed {
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return srcBuffer
                } else {
                    outStatus.pointee = .endOfStream
                    return nil
                }
            }

            if let error = error {
                print("[AnimalTTS] 변환 실패 \(url.lastPathComponent): \(error)")
                return nil
            }

            return outBuffer
        } catch {
            print("[AnimalTTS] WAV 로드 실패 \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - 공개 API

    /// 텍스트를 Animal Crossing 스타일로 재생합니다.
    func speak(_ text: String, voice: Voice = .default) {
        stop()  // 이전 재생 중단

        let profile = voice.profile
        let phonemes = HangulDecomposer.decompose(text)
            .filter { $0 != "pause" }

        guard !phonemes.isEmpty else {
            print("[AnimalTTS] 재생할 음소가 없습니다: \"\(text)\"")
            return
        }

        print("[AnimalTTS] 재생 시작: \(phonemes.count)개 음소")
        isSpeaking = true

        speakTask = Task { [weak self] in
            guard let self = self else { return }

            // 엔진이 꺼져 있으면 재시작
            if !self.audioEngine.isRunning {
                try? self.audioEngine.start()
            }

            for key in phonemes {
                guard self.isSpeaking else { break }

                let buffer = self.phonemeCache[key]
                    ?? self.phonemeCache[self.fallbackKey(for: key)]

                if let buffer = buffer {
                    let jitter = Float.random(in: -profile.pitchJitter...profile.pitchJitter)
                    let semitones = (profile.pitch - 1.0) * 12.0 + jitter * 12.0
                    self.pitchNode.pitch = semitones * 100  // cents 단위
                    self.playerNode.volume = profile.volume

                    // 이전 버퍼 중단 → 새 버퍼 스케줄 → 재생
                    self.playerNode.stop()
                    await self.playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
                    self.playerNode.play()
                }

                // 음소 간 간격 대기
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
