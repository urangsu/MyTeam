import SwiftUI

// MARK: - TTSLabView
// Round 247TTS-SUPERTONIC3-POC: Developer Lab 전용 TTS 실험실 뷰.
//
// 접근: Developer Lab 설정 화면에서만 표시.
// 기능:
//   - Supertonic3 실험용 enable 토글 (기본 off)
//   - 모델 파일 상태 표시 (checkModel() 결과)
//   - Voice preset 선택 (M1-M5, F1-F5)
//   - Probe 결과 표시 (Cloud: 모델 탐색 + 설정 요약)
//   - Qwen3 Developer Lab override 토글 (별도 섹션)
// 금지:
//   - NSOpenPanel 열기 (Mac build에서만 허용 — 248TTS에서 구현)
//   - Apple TTS 선택지 없음 (정책: 영원히 금지)
//   - 모델 자동 다운로드 없음

struct TTSLabView: View {

    // MARK: - State

    // Use safe literal defaults — real values loaded in .onAppear.
    // Avoids @MainActor isolation inference from calling UserDefaults/FileManager
    // in @State default expressions (evaluated nonisolated in Swift 5 strict concurrency).
    @State private var supertonic3Enabled: Bool = false
    @State private var selectedPreset: String = "F1"
    @State private var selectedLanguage: String = "auto"
    @State private var qwen3DevLabOverride: Bool = false
    @State private var qwen3Enabled: Bool = false
    @State private var probeResult: Supertonic3ProbeRunResult? = nil
    @State private var readinessResult: Supertonic3ProbeResult? = nil
    @State private var modelCheck: Supertonic3ModelLocator.ModelCheckResult = .checking
    @State private var showProbeDetail: Bool = false

    // MARK: - ONNX Spike State (Round 249TTS)
    @State private var spikeInputText: String = "안녕하세요. 테스트입니다."
    @State private var spikeSynthesisResult: Supertonic3SynthesisResult? = nil
    @State private var spikeSynthesisError: String? = nil
    @State private var spikeIsSynthesizing: Bool = false
    @State private var spikeWavOutputPath: String? = nil

    private let availableLanguages = ["auto", "ko", "en", "ja"]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                supertonic3Section
                onnxSpikeSection
                qwen3Section
                policyNoticeSection
            }
            .padding()
        }
        .navigationTitle("TTS 실험실")
        .onAppear {
            // Restore persisted settings (deferred from @State defaults to avoid @MainActor inference)
            supertonic3Enabled = UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled")
            selectedPreset = UserDefaults.standard.string(forKey: "supertonic3VoicePreset") ?? "F1"
            selectedLanguage = UserDefaults.standard.string(forKey: "supertonic3Language") ?? "auto"
            qwen3DevLabOverride = UserDefaults.standard.bool(forKey: "ttsDevLabQwen3Override")
            qwen3Enabled = UserDefaults.standard.bool(forKey: "enableExperimentalQwenTTS")
            refreshModelCheck()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("TTS 실험실 (Developer Only)", systemImage: "waveform")
                .font(.title2.bold())
            Text("실험용 TTS provider 설정. 기본 비활성화. 운영 환경에서 사용 금지.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
        }
    }

    private var supertonic3Section: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {

                // Enable toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supertonic3 TTS (실험용)")
                            .font(.headline)
                        Text("로컬 ONNX 모델 필요 (~398 MB) · Cloud 환경에서 synthesize 불가")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $supertonic3Enabled)
                        .toggleStyle(.switch)
                        .onChange(of: supertonic3Enabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "supertonic3ExperimentalEnabled")
                            refreshModelCheck()
                        }
                }

                Divider()

                // Model directory path (redacted — no full path shown)
                VStack(alignment: .leading, spacing: 4) {
                    Text("모델 디렉토리")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(modelCheck.redactedDirectory)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    Text("※ 전체 경로는 보안을 위해 표시하지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Model check result
                modelCheckView

                Divider()

                // Voice preset picker
                HStack {
                    Text("Voice Preset")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $selectedPreset) {
                        ForEach(Supertonic3TTSConfig.availableVoicePresets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .onChange(of: selectedPreset) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "supertonic3VoicePreset")
                    }
                }

                // Language picker
                HStack {
                    Text("언어")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $selectedLanguage) {
                        ForEach(availableLanguages, id: \.self) { lang in
                            Text(lang == "auto" ? "자동" : lang.uppercased()).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .onChange(of: selectedLanguage) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "supertonic3Language")
                    }
                }

                Divider()

                // Probe button + result
                probeSection
            }
            .padding(8)
        } label: {
            Label("Supertonic3", systemImage: "cpu.fill")
        }
    }

    @ViewBuilder
    private var modelCheckView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("파일 상태")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("새로고침") { refreshModelCheck() }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }

            if modelCheck.isAvailable {
                Label("모든 파일 준비됨 (\(modelCheck.totalFoundSizeBytes / 1_048_576) MB)",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if !modelCheck.foundFiles.isEmpty {
                        Label("\(modelCheck.foundFiles.count)개 있음: \(modelCheck.foundFiles.joined(separator: ", "))",
                              systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !modelCheck.missingFiles.isEmpty {
                        Label("없음: \(modelCheck.missingFiles.joined(separator: ", "))",
                              systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if !modelCheck.modelDirectoryExists {
                        Text("디렉토리 없음: ~/.cache/supertonic3/onnx/")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Download guide (only if missing)
            if !modelCheck.isAvailable {
                DisclosureGroup("다운로드 방법") {
                    Text(Supertonic3ModelLocator.downloadGuideMessage())
                        .font(.system(.caption, design: .monospaced))
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                }
                .font(.caption)
            }
        }
    }

    private var probeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    readinessResult = Supertonic3TTSProbe.probe()
                    probeResult = Supertonic3TTSProbe.run()
                    showProbeDetail = true
                } label: {
                    Label("Probe 실행", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .font(.caption)

                if let result = readinessResult {
                    Text(readinessBadge(result.readiness))
                        .font(.caption)
                        .foregroundStyle(result.readiness == .readyForInference ? .green : .orange)
                }
            }

            if showProbeDetail, let result = probeResult {
                Text(result.detailedSummary)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(6)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - ONNX Spike Section (Round 249TTS)

    private var onnxSpikeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supertonic3 ONNX Spike")
                            .font(.headline)
                        Text("[실험용] Swift ONNX Runtime 직접 호출 · Developer Lab 전용")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("SPIKE", systemImage: "flask.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }

                Divider()

                // Model availability
                HStack(spacing: 6) {
                    Image(systemName: modelCheck.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(modelCheck.isAvailable ? Color.green : Color.red)
                    Text(modelCheck.isAvailable
                         ? "모델 준비됨 (\(modelCheck.totalFoundSizeBytes / 1_048_576) MB)"
                         : "모델 없음 — ~/.cache/supertonic3/onnx/ 필요")
                        .font(.caption)
                }

                // RTF gauge (if measured)
                if let result = spikeSynthesisResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                        HStack {
                            Text("RTF")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.4fx", result.realtimeFactor))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(result.realtimeFactor < 0.5 ? .green : .orange)
                        }
                        HStack {
                            Text("시간")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f ms → %.2f s 오디오", result.elapsedMs, result.durationSec))
                                .font(.system(.caption, design: .monospaced))
                        }
                        HStack {
                            Text("텍스트")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(result.textLength) 토큰 · L=\(result.latentFrameCount) 프레임 · \(result.presetUsed)")
                                .font(.system(.caption, design: .monospaced))
                        }
                        HStack {
                            Text("샘플")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(result.wavSamples.count) samples @ \(result.sampleRate) Hz")
                                .font(.system(.caption, design: .monospaced))
                        }
                        if let wavPath = spikeWavOutputPath {
                            HStack {
                                Text("WAV")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(wavPath)
                                    .font(.system(.caption2, design: .monospaced))
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }

                if let err = spikeSynthesisError {
                    Text("오류: \(err)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .padding(6)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(4)
                }

                Divider()

                // Text input
                VStack(alignment: .leading, spacing: 4) {
                    Text("합성 텍스트")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextField("텍스트 입력...", text: $spikeInputText, axis: .vertical)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3)
                }

                // Synthesize button
                HStack {
                    Button {
                        runONNXSpike()
                    } label: {
                        if spikeIsSynthesizing {
                            ProgressView().scaleEffect(0.7)
                            Text("합성 중...")
                        } else {
                            Label("ONNX 합성 실행", systemImage: "waveform.badge.plus")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(spikeIsSynthesizing || !modelCheck.isAvailable || spikeInputText.isEmpty)
                    .font(.caption)

                    Spacer()

                    // Readiness summary
                    let readiness = SupertonicProductReadiness()
                    Text(readiness.isProductionReady ? "✅ 프로덕션 준비됨" : "⬜ 스파이크 단계")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Policy reminder
                Text("※ 이 기능은 스파이크 전용입니다. 프로덕션 TTS 경로(SpeechManager)에 연결되어 있지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        } label: {
            Label("ONNX Spike (249TTS)", systemImage: "cpu.fill")
                .foregroundStyle(.orange)
        }
    }

    private func runONNXSpike() {
        guard !spikeInputText.isEmpty else { return }
        let text = spikeInputText
        let preset = selectedPreset
        let lang: String? = selectedLanguage == "auto" ? "ko" : selectedLanguage
        let paths = Supertonic3ONNXModelPaths.defaultPaths()

        spikeSynthesisError = nil
        spikeSynthesisResult = nil
        spikeIsSynthesizing = true

        Task {
            do {
                let result = try await Supertonic3ONNXRunner.shared.synthesize(
                    text: text,
                    preset: preset,
                    lang: lang,
                    totalSteps: 8,
                    paths: paths
                )
                // Save wav to ~/Desktop for afplay verification
                let wavPath = S3WavWriter.write(
                    samples: result.wavSamples,
                    sampleRate: result.sampleRate,
                    tag: "spike_\(result.presetUsed)")
                await MainActor.run {
                    spikeSynthesisResult = result
                    spikeWavOutputPath = wavPath
                    spikeIsSynthesizing = false
                }
            } catch {
                await MainActor.run {
                    spikeSynthesisError = error.localizedDescription
                    spikeIsSynthesizing = false
                }
            }
        }
    }

    private var qwen3Section: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Qwen3-TTS (MLX 4bit)")
                            .font(.headline)
                        Text("기본 비활성화. Developer Lab override가 켜져 있어야만 활성화 가능.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Dev Lab override toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Developer Lab Override")
                            .font(.subheadline)
                        Text("이 스위치를 켠 뒤 아래 실험 플래그도 켜야 Qwen3 활성화됨")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $qwen3DevLabOverride)
                        .toggleStyle(.switch)
                        .onChange(of: qwen3DevLabOverride) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "ttsDevLabQwen3Override")
                        }
                }

                if qwen3DevLabOverride {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("실험용 Qwen3 TTS 활성화")
                                .font(.subheadline)
                            Text("enableExperimentalQwenTTS — DevLab override ON 상태에서만 유효")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $qwen3Enabled)
                            .toggleStyle(.switch)
                            .onChange(of: qwen3Enabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "enableExperimentalQwenTTS")
                            }
                    }
                    .padding(.leading, 16)
                }
            }
            .padding(8)
        } label: {
            Label("Qwen3-TTS", systemImage: "cpu")
        }
    }

    private var policyNoticeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label("정책 고지", systemImage: "info.circle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("• Apple TTS (AVSpeechSynthesizer): 영원히 금지 (폴백 포함)\n• 모델 자동 다운로드: 금지\n• 라이선스: MIT (code) + OpenRAIL-M (model) — App Store 배포 미검증\n• 모델 파일은 repo에 포함하지 않음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }

    // MARK: - Helpers

    private func readinessBadge(_ readiness: Supertonic3Readiness) -> String {
        switch readiness {
        case .disabled: return "⏸ 비활성화"
        case .missingModel: return "⚠️ 모델 없음"
        case .runtimeUnavailable: return "⚠️ Runtime 없음 (Mac 필요)"
        case .readyForInference: return "✅ 사용 가능"
        }
    }

    private func refreshModelCheck() {
        modelCheck = Supertonic3ModelLocator.checkModel()
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        TTSLabView()
    }
    .frame(width: 480, height: 700)
}
#endif
