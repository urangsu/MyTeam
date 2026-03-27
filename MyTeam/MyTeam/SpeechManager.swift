import Foundation
import Combine
import Speech
import AVFoundation
import AppKit

class SpeechManager: NSObject, ObservableObject, @unchecked Sendable, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()
    
    // TTS (Apple Native)
    private let synthesizer = AVSpeechSynthesizer()
    
    // TTS (Cloud Audio)
    private var audioPlayer: AVAudioPlayer?
    @Published var isSpeaking: Bool = false
    
    // STT (Apple Native)
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isStarting = false
    @Published var isRecording: Bool = false
    @Published var recognizedText: String = ""
    @Published var sttError: String? = nil
    
    override private init() {
        super.init()
        synthesizer.delegate = self
        speechRecognizer?.delegate = self
    }
    
    // MARK: - STT 권한 요청 로직 (macOS 전용 하드웨어 마이크 권한 필수)
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // 0단계: 마이크 기기 자체가 연결되어 있는지 확인 (맥미니 멈춤 현상 원인)
        let defaultAudioDevice = AVCaptureDevice.default(for: .audio)
        guard defaultAudioDevice != nil else {
            DispatchQueue.main.async {
                self.sttError = "연결된 마이크가 없습니다. 마이크를 연결해 주세요."
                completion(false)
            }
            return
        }
        
        // 1단계: macOS 고유 마이크(하드웨어) 권한 요청
        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            DispatchQueue.main.async {
                if !micGranted {
                    self.sttError = "마이크 권한이 거부되었습니다. 시스템 설정 > 개인정보 보호에서 마이크 권한을 허용해주세요."
                    completion(false)
                    return
                }
                
                // 2단계: Apple 음성 인식(소프트웨어) 권한 요청
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    DispatchQueue.main.async {
                        if authStatus != .authorized {
                            self.sttError = "음성 인식 권한이 없습니다. 시스템 환경설정을 확인하세요."
                        }
                        completion(authStatus == .authorized)
                    }
                }
            }
        }
    }
    
    // MARK: - 녹음 시작
    func startRecording() {
        guard !isRecording, !isStarting else {
            stopRecording()
            return
        }
        
        isStarting = true
        self.sttError = nil
        self.recognizedText = ""
        
        // AVAudioEngine은 macOS에서 철저히 메인 스레드에서 설정해야 크래시를 피할 수 있다고 생각했지만,
        // 싱글톤 패턴이 정립된 지금, inputNode 최초 하드웨어 연결 시 메인 스레드를 블로킹하는 현상을 방지하기 위해 
        // 권한 분리 후 AudioEngine 시동만 백그라운드로 넘깁니다.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.startAudioEngine()
                DispatchQueue.main.async {
                    self.isStarting = false
                    self.isRecording = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isStarting = false
                    self.isRecording = false
                    self.sttError = "마이크 오류: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - 녹음 정지
    func stopRecording() {
        // 기존 탭(Tap)부터 안전하게 해제
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        self.isRecording = false
        self.isStarting = false
    }
    
    // MARK: - 엔진 셋업
    private func startAudioEngine() throws {
        // 1. 기존 잔재 완전 정리
        recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest = nil
        
        // 2. 인식기 가용성 확인
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "Speech", code: -1, userInfo: [NSLocalizedDescriptionKey: "음성 인식기를 현재 사용할 수 없습니다."])
        }
        
        // 3. 엔진 노드 확보 및 탭 초기화
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0) // installTap 전 반드시 이전 tap 제거
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            throw NSError(domain: "Speech", code: -2, userInfo: [NSLocalizedDescriptionKey: "마이크 초기화 실패(SampleRate 0)"])
        }
        guard recordingFormat.channelCount > 0 else {
            throw NSError(domain: "Speech", code: -3, userInfo: [NSLocalizedDescriptionKey: "마이크 초기화 실패(ChannelCount 0)"])
        }
        
        // 4. 요청 및 태스크 생성
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        self.recognitionRequest = newRequest
        
        recognitionTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                // 에러 발생이나 종료 시 즉각 정리
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
        
        // 5. 콜백 탭 설치
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // 6. 엔진 시동
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // MARK: - TTS (Text to Speech)
    // useAnimalTTS(AppStorage) = true  → 동물의 숲 스타일 (AnimalTTSManager)
    // useAnimalTTS(AppStorage) = false → Apple 기본 TTS (AVSpeechSynthesizer)
    func speak(text: String, voiceIdentifier: String? = nil) {
        let useAnimal = UserDefaults.standard.bool(forKey: "useAnimalTTS")

        if useAnimal {
            DispatchQueue.main.async { self.isSpeaking = true }
            AnimalTTSManager.shared.speak(text)
            // 재생 시간 추정 후 isSpeaking 해제 (글자 수 × 간격 + 여유)
            let estimatedDuration = Double(text.count) * 0.12 + 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) {
                self.isSpeaking = false
            }
            return
        }

        let utterance = AVSpeechUtterance(string: text)

        if let v = voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: v)
        } else {
            let koreanVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.contains("ko") }
            if let yuna = koreanVoices.first(where: { $0.identifier.lowercased().contains("yuna") }) ?? koreanVoices.first {
                utterance.voice = yuna
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            }
        }

        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        AnimalTTSManager.shared.stop()
        if let player = audioPlayer, player.isPlaying { player.stop() }
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func playAudioData(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
            DispatchQueue.main.async {
                self.isSpeaking = true
            }
        } catch {
            print("Audio Player Error: \(error.localizedDescription)")
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
