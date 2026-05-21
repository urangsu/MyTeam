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

    @State private var supertonic3Enabled: Bool = Supertonic3TTSConfig.isEnabled
    @State private var selectedPreset: String = Supertonic3TTSConfig.selectedVoicePreset
    @State private var selectedLanguage: String = Supertonic3TTSConfig.selectedLanguage
    @State private var qwen3DevLabOverride: Bool = UserDefaults.standard.bool(forKey: "ttsDevLabQwen3Override")
    @State private var qwen3Enabled: Bool = UserDefaults.standard.bool(forKey: "enableExperimentalQwenTTS")
    @State private var probeResult: Supertonic3ProbeRunResult? = nil
    @State private var readinessResult: Supertonic3ProbeResult? = nil
    @State private var modelCheck: Supertonic3ModelLocator.ModelCheckResult = Supertonic3ModelLocator.checkModel()
    @State private var showProbeDetail: Bool = false

    private let availableLanguages = ["auto", "ko", "en", "ja"]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                supertonic3Section
                qwen3Section
                policyNoticeSection
            }
            .padding()
        }
        .navigationTitle("TTS 실험실")
        .onAppear { refreshModelCheck() }
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
                    .padding(6)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)
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
