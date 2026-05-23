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
    @State private var probeResult: Supertonic3ProbeRunResult? = nil
    @State private var readinessResult: Supertonic3ProbeResult? = nil
    @State private var modelCheck: Supertonic3ModelLocator.ModelCheckResult = .checking
    @State private var showProbeDetail: Bool = false

    // MARK: - Round 258TTS: Voice Director State
    @State private var voiceDirectorSpeakingID: String? = nil   // speaking agentID or preset
    @State private var voiceDirectorError: String? = nil

    // MARK: - ONNX Spike State (Round 249TTS)
    @State private var spikeInputText: String = "안녕하세요. 테스트입니다."
    @State private var spikeSynthesisResult: Supertonic3SynthesisResult? = nil
    @State private var spikeSynthesisError: String? = nil
    @State private var spikeIsSynthesizing: Bool = false
    @State private var spikeWavOutputPath: String? = nil

    // MARK: - Notice Gate State (Round 254TTS-NOTICE)
    @State private var noticeAccepted: Bool = false

    private let availableLanguages = ["auto", "ko", "en", "ja"]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                officialEngineStatusSection
                supertonicNoticeSection
                voiceDirectorSection
                supertonic3Section
                onnxSpikeSection
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
            noticeAccepted = SupertonicTTSNoticePolicy.isCurrentNoticeAccepted
            refreshModelCheck()
        }
    }

    // MARK: - Sections

    // MARK: - Official Engine Status (Round 256TTS-OFFICIAL-ENGINE)

    private var officialEngineStatusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("공식 TTS 엔진")
                        .font(.headline)
                    Spacer()
                    Text("Supertonic3")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(5)
                }
                Divider()
                let routing = TTSRoutingPolicy.availabilitySummary()[.supertonic3]
                let isReady = TTSRoutingPolicy.isSupertonic3Available
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("공식 엔진").font(.caption).foregroundStyle(.secondary)
                        Text("Supertonic3").font(.caption.bold())
                    }
                    GridRow {
                        Text("자동 재생 기본값").font(.caption).foregroundStyle(.secondary)
                        Text("꺼짐").font(.caption).foregroundStyle(.orange)
                    }
                    GridRow {
                        Text("캐릭터 말하기").font(.caption).foregroundStyle(.secondary)
                        Text(TTSProductPolicy.characterVoiceEnabled ? "사용 가능" : "비활성").font(.caption)
                    }
                    GridRow {
                        Text("fallback").font(.caption).foregroundStyle(.secondary)
                        Text("없음").font(.caption).foregroundStyle(.secondary)
                    }
                    GridRow {
                        Text("현재 preset").font(.caption).foregroundStyle(.secondary)
                        Text(selectedPreset).font(.system(.caption, design: .monospaced))
                    }
                    GridRow {
                        Text("모델").font(.caption).foregroundStyle(.secondary)
                        Text(modelCheck.isAvailable ? "ready (\(modelCheck.totalFoundSizeBytes / 1_048_576) MB)" : "없음")
                            .font(.caption)
                            .foregroundStyle(modelCheck.isAvailable ? .green : .red)
                    }
                    GridRow {
                        Text("runtime").font(.caption).foregroundStyle(.secondary)
                        Text(Supertonic3ONNXRuntimeProbe.isRuntimeLinked ? "linked" : "미탑재")
                            .font(.caption)
                            .foregroundStyle(Supertonic3ONNXRuntimeProbe.isRuntimeLinked ? .green : .red)
                    }
                    GridRow {
                        Text("notice").font(.caption).foregroundStyle(.secondary)
                        Text(noticeAccepted ? "accepted" : "미수락")
                            .font(.caption)
                            .foregroundStyle(noticeAccepted ? .green : .orange)
                    }
                    GridRow {
                        Text("routing").font(.caption).foregroundStyle(.secondary)
                        Text(isReady ? "✅ supertonic3" : "⏸ \(routing?.rawValue ?? "unavailable")")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(isReady ? .green : .orange)
                    }
                }
            }
            .padding(4)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("TTS 실험실 (Developer Only)", systemImage: "waveform")
                .font(.title2.bold())
            Text("Supertonic3 공식 TTS 엔진. 자동 재생 기본 OFF. 수동 말하기만 허용.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
        }
    }

    // MARK: - Notice Section (Round 254TTS-NOTICE)

    private var supertonicNoticeSection: some View {
        SupertonicNoticeCardView(
            accepted: $noticeAccepted,
            onAccept: {
                SupertonicTTSNoticePolicy.acceptCurrentNotice()
                noticeAccepted = true
            },
            onReset: {
                SupertonicTTSNoticePolicy.resetNoticeAcceptance()
                noticeAccepted = false
            }
        )
    }

    // MARK: - Round 258TTS: Voice Director Section

    private var voiceDirectorSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {

                HStack(spacing: 8) {
                    Image(systemName: "music.microphone")
                        .foregroundStyle(.purple)
                    Text("보이스 디렉터")
                        .font(.headline)
                    Spacer()
                    Text("Round 258TTS")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(4)
                }

                if let err = voiceDirectorError {
                    Text("오류: \(err)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(4)
                }

                Divider()

                // MARK: Preset 전체 테스트 (M1~M5, F1~F5)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preset 전체 테스트")
                        .font(.subheadline.bold())
                    Text("각 버튼: \"안녕하세요. 제 목소리는 이 톤이에요.\" 발화")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let presets = ["M1", "M2", "M3", "M4", "M5", "F1", "F2", "F3", "F4", "F5"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
                        ForEach(presets, id: \.self) { preset in
                            let agentID = CharacterVoiceProfileCatalog.profile(forPreset: preset)?.agentID
                            let isSpeaking = voiceDirectorSpeakingID == "preset_\(preset)"
                            Button(action: {
                                speakVoiceDirectorSample(
                                    text: "안녕하세요. 제 목소리는 이 톤이에요.",
                                    agentID: agentID,
                                    speakID: "preset_\(preset)"
                                )
                            }) {
                                VStack(spacing: 2) {
                                    if isSpeaking {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "speaker.wave.2")
                                            .font(.caption2)
                                    }
                                    Text(preset)
                                        .font(.system(.caption, design: .monospaced).bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .tint(preset.hasPrefix("M") ? .blue : .pink)
                            .disabled(voiceDirectorSpeakingID != nil || !modelCheck.isAvailable || !noticeAccepted)
                        }
                    }
                }

                Divider()

                // MARK: 캐릭터 목소리 매핑 테이블
                VStack(alignment: .leading, spacing: 6) {
                    Text("캐릭터 목소리 매핑")
                        .font(.subheadline.bold())

                    ForEach(CharacterVoiceProfileCatalog.profiles) { profile in
                        let isSpeaking = voiceDirectorSpeakingID == "char_\(profile.agentID)"
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(profile.displayName)
                                    .font(.caption.bold())
                                    .frame(width: 44, alignment: .leading)
                                Text(profile.preset)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                Text(String(format: "p%+.0f r%.2f s%.2f",
                                             profile.basePitch, profile.baseRate, profile.baseSpeed))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(action: {
                                    speakVoiceDirectorSample(
                                        text: profile.sampleLine,
                                        agentID: profile.agentID,
                                        speakID: "char_\(profile.agentID)"
                                    )
                                }) {
                                    if isSpeaking {
                                        ProgressView().scaleEffect(0.5)
                                    } else {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .disabled(voiceDirectorSpeakingID != nil || !modelCheck.isAvailable || !noticeAccepted)
                            }
                            Text(profile.sampleLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 52)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(
                            isSpeaking ? Color.purple.opacity(0.08) : Color.clear
                        )
                        .cornerRadius(4)
                    }
                }

                // Disabled notice
                if !noticeAccepted || !modelCheck.isAvailable {
                    Text(noticeAccepted ? "⚠️ 모델 파일 없음 — ~/.cache/supertonic3/onnx/ 필요" : "📋 Supertonic 고지 수락 후 사용 가능")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(8)
        } label: {
            Label("보이스 디렉터", systemImage: "music.microphone")
                .foregroundStyle(.purple)
        }
    }

    private func speakVoiceDirectorSample(text: String, agentID: String?, speakID: String) {
        guard voiceDirectorSpeakingID == nil else { return }
        voiceDirectorSpeakingID = speakID
        voiceDirectorError = nil
        Task {
            let output = await SpeechManager.shared.speakOnce(text: text, agentID: agentID)
            await MainActor.run {
                voiceDirectorSpeakingID = nil
                if output == nil {
                    voiceDirectorError = "재생 실패 — TTS 미설정 또는 모델 없음"
                }
            }
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

                // Synthesize button (notice acceptance required — Round 254TTS-NOTICE)
                if !noticeAccepted {
                    Text("Supertonic 고지와 사용 제한을 확인해야 ONNX 합성을 실행할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(6)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(4)
                }

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
                    .disabled(spikeIsSynthesizing || !modelCheck.isAvailable || spikeInputText.isEmpty || !noticeAccepted)
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

    private var policyNoticeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label("정책 고지", systemImage: "info.circle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("• Supertonic은 유일한 TTS 후보입니다\n• 모델 자동 다운로드: 금지\n• 상업 사용/모델 재배포/App Store 번들 정책: 제품 gate에서 별도 검토\n• 모델 파일은 repo와 앱 번들에 포함하지 않음\n• gate 실패 시 MyTeam v1은 TTS 없이 출시")
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
        case .noticeRequired: return "📋 고지 수락 필요"
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