import Foundation
import Combine
import AVFoundation
import Speech

// MARK: - AudioCaptureService
// 오로지 "오디오 버퍼를 받아 STT 엔진으로 안전하게 스트리밍"하는 것만 책임진다.
// ✅ 권한 요청 코드 없음 → PermissionsManager에 완전히 위임
// ✅ Barge-in 지원: 재생 중에도 마이크를 절대로 끄지 않는다.
//
// ⚠️ TODO (AVAudioEnginePlaybackService 전환 시 반드시 처리):
//   let inputNode = audioEngine.inputNode
//   try inputNode.setVoiceProcessingEnabled(true)
//   위 한 줄을 활성화하면 하드웨어 레벨 AEC(Acoustic Echo Cancellation)가 켜져
//   AI 스피커 출력이 마이크에 피드백되는 에코/하울링을 완전히 차단할 수 있다.
//   이 방식이 켜지면 현재 SpeechManager의 임시 barge-in 감지 로직도 제거 가능.
final class AudioCaptureService: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = AudioCaptureService()

    // MARK: - Published State
    @Published var isRecording: Bool = false
    @Published var isStarting: Bool = false
    @Published var recognizedText: String = ""
    @Published var sttError: String? = nil

    // MARK: - Private
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Barge-in 감지: 재생 중에도 마이크는 열려 있음.
    // AI가 말하는 중에 사용자가 끼어들면 이 콜백이 발동됨.
    var onBargeInDetected: (() -> Void)?

    private override init() {
        super.init()
        speechRecognizer?.delegate = nil
    }

    // MARK: - 녹음 시작 (권한은 이미 PermissionsManager가 획득한 상태여야 한다)
    func startRecording() {
        guard !isRecording, !isStarting else {
            stopRecording()
            return
        }

        isStarting = true
        sttError = nil
        recognizedText = ""

        // AVAudioEngine InputNode는 백그라운드에서 초기화해야 메인 스레드 블로킹 방지
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try self.setupAndStartEngine()
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
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.isStarting = false
        }
    }

    // MARK: - 엔진 셋업 (백그라운드 스레드에서 실행, 메인 스레드 블로킹 없음)
    private func setupAndStartEngine() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "STT", code: -1, userInfo: [NSLocalizedDescriptionKey: "음성 인식기를 현재 사용할 수 없습니다."])
        }

        let inputNode = audioEngine.inputNode

        // TODO: AVAudioEnginePlaybackService 전환 시 아래 줄 활성화 → 하드웨어 AEC 켜짐
        // try inputNode.setVoiceProcessingEnabled(true)

        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            throw NSError(domain: "STT", code: -2, userInfo: [NSLocalizedDescriptionKey: "마이크 초기화 실패(SampleRate 0)"])
        }
        guard recordingFormat.channelCount > 0 else {
            throw NSError(domain: "STT", code: -3, userInfo: [NSLocalizedDescriptionKey: "마이크 초기화 실패(ChannelCount 0)"])
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.recognizedText = text }

                // Barge-in 감지: 재생 중에 사용자 음성이 감지되면 콜백 발동
                DispatchQueue.main.async { self.onBargeInDetected?() }
            }

            if error != nil || (result?.isFinal ?? false) {
                // ⚠️ 탭 컬백 내에서 메인 스레드를 절대 블로킹하지 않음
                // audioEngine.stop()은 별도 큐에서
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.audioEngine.stop()
                    self?.audioEngine.inputNode.removeTap(onBus: 0)
                    self?.recognitionRequest = nil
                    self?.recognitionTask = nil
                    DispatchQueue.main.async { self?.isRecording = false }
                }
            }
        }

        // 탭 콜백은 항상 백그라운드 큐에서 실행 (메인 스레드 블로킹 절대 금지)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }
}
