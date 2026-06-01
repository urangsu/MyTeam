import SwiftUI

struct TTSLabView: View {
    @AppStorage("supertonic3ExperimentalEnabled") private var experimentalEnabled: Bool = false
    @AppStorage("useAnimalCrossingTTS") private var useAnimaleseEffect: Bool = false

    @State private var selectedProfileID: String = CharacterVoiceProfileCatalog.profiles.first?.id ?? ""
    @State private var selectedEmotion: SupertonicEmotionStyle = .friendly
    @State private var animaleseProfile: AnimaleseVoiceProfile = .cute
    @State private var sampleText: String = "좋아요. 핵심만 짧게 정리해서 말씀드릴게요."
    @State private var tempPitch: Double = 0
    @State private var tempRate: Double = 1.0
    @State private var tempSpeed: Double = 1.0
    @State private var useExpressionTags: Bool = false
    @State private var noticeAccepted: Bool = SupertonicTTSNoticePolicy.isCurrentNoticeAccepted
    @State private var previewStatus: String = "아직 실행하지 않았습니다."
    @State private var isPreviewing = false

    private var selectedProfile: CharacterVoiceProfile {
        CharacterVoiceProfileCatalog.profiles.first { $0.id == selectedProfileID }
            ?? CharacterVoiceProfileCatalog.profiles[0]
    }

    private var processedText: String {
        SupertonicProsodyTextProcessor.preprocess(
            sampleText,
            agentID: selectedProfile.agentID,
            style: selectedEmotion,
            useExpressionTags: useExpressionTags
        )
    }

    private var canRunPreview: Bool {
        TTSRoutingPolicy.selectedProvider() != nil
            && TTSProductPolicy.modelBundled
            && experimentalEnabled
            && noticeAccepted
            && !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canRunAudioPathTest: Bool {
        noticeAccepted && !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                SupertonicNoticeCardView(
                    accepted: noticeAccepted,
                    onAccept: {
                        SupertonicTTSNoticePolicy.acceptCurrentNotice()
                        noticeAccepted = true
                    },
                    onReset: {
                        SupertonicTTSNoticePolicy.resetNoticeAcceptance()
                        noticeAccepted = false
                    }
                )
                runtimeCard
                voiceControls
                sampleEditor
                outputCard
            }
            .padding(16)
            .frame(maxWidth: 620, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            if selectedProfileID.isEmpty {
                selectedProfileID = CharacterVoiceProfileCatalog.profiles.first?.id ?? ""
            }
            noticeAccepted = SupertonicTTSNoticePolicy.isCurrentNoticeAccepted
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TTS Lab")
                .font(.title3.weight(.bold))
            Text("현재 캐릭터 TTS provider는 비활성입니다. 이 탭은 목소리 설정값과 오디오 경로만 검토합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $experimentalEnabled) {
                Label("Supertonic3 실험 모드", systemImage: "slider.horizontal.3")
            }
            .toggleStyle(.switch)
            .disabled(!TTSProductPolicy.labOnlyEnabled)

            Toggle(isOn: $useAnimaleseEffect) {
                Label("오디오 경로 테스트 허용", systemImage: "waveform.path")
            }
            .toggleStyle(.switch)

            compactStatusGrid
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var compactStatusGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            statusPill("기본 자동 재생", TTSProductPolicy.autoSpeakDefaultEnabled ? "ON" : "OFF")
            statusPill("사용자 TTS", TTSProductPolicy.userFacingTTSEnabled ? "ON" : "OFF")
            statusPill("캐릭터 합성", TTSRoutingPolicy.isSupertonic3Available ? "가능" : "없음")
            statusPill("모델 번들", TTSProductPolicy.modelBundled ? "포함" : "미포함")
        }
    }

    private func statusPill(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var voiceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Picker("캐릭터", selection: $selectedProfileID) {
                    ForEach(CharacterVoiceProfileCatalog.profiles) { profile in
                        Text("\(profile.localizedDisplayName) · \(profile.preset)").tag(profile.id)
                    }
                }
                .frame(maxWidth: .infinity)

                Picker("감정", selection: $selectedEmotion) {
                    ForEach(SupertonicEmotionStyle.allCases, id: \.self) { emotion in
                        Text(emotionLabel(emotion)).tag(emotion)
                    }
                }
                .frame(maxWidth: 170)
            }

            Text(selectedProfile.styleNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                labSlider("Pitch", value: $tempPitch, range: -120...120, label: "\(Int(tempPitch))")
                labSlider("Rate", value: $tempRate, range: 0.9...1.14, label: String(format: "%.2f", tempRate))
                labSlider("Speed", value: $tempSpeed, range: 0.85...1.25, label: String(format: "%.2f", tempSpeed))
            }

            Toggle("Expression tag 포함", isOn: $useExpressionTags)
                .font(.caption)

            Picker("오디오 테스트", selection: $animaleseProfile) {
                ForEach(AnimaleseVoiceProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func labSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .frame(width: 46, alignment: .leading)
            Slider(value: value, in: range)
            Text(label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var sampleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("테스트 문장")
                    .font(.headline)
                Spacer()
                Button("프로필 샘플") { sampleText = selectedProfile.sampleLine }
                    .controlSize(.small)
            }

            TextEditor(text: $sampleText)
                .font(.body)
                .frame(minHeight: 72, maxHeight: 108)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                Button {
                    runPreview()
                } label: {
                    Label("캐릭터 TTS 미리듣기", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canRunPreview || isPreviewing)

                Button {
                    runAudioPathTest()
                } label: {
                    Label("오디오 경로 테스트", systemImage: "waveform")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canRunAudioPathTest || !useAnimaleseEffect || isPreviewing)

                Button {
                    previewStatus = "전처리 결과를 갱신했습니다."
                } label: {
                    Label("전처리 확인", systemImage: "text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !noticeAccepted {
                    Text("고지 수락 필요")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("전처리 출력")
                .font(.headline)
            Text(processedText)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(previewStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func runPreview() {
        if !noticeAccepted {
            previewStatus = "고지 수락 후 캐릭터 TTS 상태를 확인할 수 있습니다."
            return
        }
        guard canRunPreview else {
            previewStatus = "캐릭터 TTS provider가 없습니다. 모델 미포함/릴리즈 gate 보류 상태라 합성 미리듣기는 비활성입니다."
            return
        }
        isPreviewing = true
        previewStatus = "합성 요청 중..."
        Task {
            let output = await SpeechManager.shared.previewWithTuning(
                text: processedText,
                preset: selectedProfile.preset,
                pitch: Float(tempPitch + Double(selectedProfile.basePitch)),
                rate: Float(tempRate),
                speed: Float(tempSpeed),
                emotion: selectedEmotion,
                agentID: selectedProfile.agentID,
                label: "tts_lab_preview",
                useExpressionTags: useExpressionTags
            )
            await MainActor.run {
                isPreviewing = false
                if let output, output.audioFileURL != nil {
                    previewStatus = "캐릭터 TTS 미리듣기를 실행했습니다."
                } else {
                    previewStatus = "합성 런타임이 응답하지 않았습니다. 캐릭터 TTS는 성공 처리하지 않았습니다."
                }
            }
        }
    }

    private func runAudioPathTest() {
        guard noticeAccepted else {
            previewStatus = "고지 수락 후 오디오 경로 테스트를 실행할 수 있습니다."
            return
        }
        isPreviewing = true
        previewStatus = "오디오 경로 테스트 재생 중..."
        Task {
            let output = await SpeechManager.shared.previewAnimalese(
                text: processedText,
                profile: animaleseProfile,
                speed: Float(tempSpeed),
                pitchOffset: Float(tempPitch),
                label: "tts_lab_audio_path"
            )
            await MainActor.run {
                isPreviewing = false
                if let output, output.duration ?? 0 > 0 {
                    previewStatus = "오디오 경로 테스트를 재생했습니다. 실제 캐릭터 목소리 합성은 아닙니다."
                } else {
                    previewStatus = "오디오 경로 테스트도 실패했습니다. 출력 장치/오디오 엔진 상태를 확인해야 합니다."
                }
            }
        }
    }

    private func emotionLabel(_ emotion: SupertonicEmotionStyle) -> String {
        switch emotion {
        case .neutral: return "중립"
        case .friendly: return "친근"
        case .confident: return "자신감"
        case .careful: return "신중"
        case .excited: return "신남"
        case .animalCrossing: return "강한 효과"
        }
    }
}
