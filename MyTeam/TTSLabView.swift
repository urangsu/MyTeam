import SwiftUI

struct TTSLabView: View {
    @AppStorage("supertonic3ExperimentalEnabled") private var experimentalEnabled: Bool = false
    @AppStorage("useBubbleSpeechEffect") private var useBubbleSpeechEffect: Bool = false

    @State private var selectedProfileID: String = CharacterVoiceProfileCatalog.profiles.first?.id ?? ""
    @State private var selectedEmotion: SupertonicEmotionStyle = .friendly
    @State private var bubbleSpeechProfile: BubbleSpeechVoiceProfile = .cute
    @State private var sampleText: String = "좋아요. 핵심만 짧게 정리해서 말씀드릴게요."
    @State private var tempPitch: Double = 0
    @State private var tempRate: Double = 1.0
    @State private var tempSpeed: Double = 1.0
    @State private var useExpressionTags: Bool = false
    @State private var noticeAccepted: Bool = SupertonicTTSNoticePolicy.isCurrentNoticeAccepted
    @State private var previewStatus: String = "아직 실행하지 않았습니다."
    @State private var isPreviewing = false
    @State private var showDiagnostics = false

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
        TTSRoutingPolicy.selectedProvider() == .supertonic3
            && experimentalEnabled
            && noticeAccepted
            && !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canRunBubbleSpeechEffect: Bool {
        canRunPreview
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                labGuardCard
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
                statusCard
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
            Text("캐릭터 목소리")
                .font(.title3.weight(.bold))
            Text("Supertonic3는 메인 TTS 엔진이고, 뽀글뽀글 말하기는 캐릭터 보이스 위에 얹는 BubbleSpeech 효과입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var labGuardCard: some View {
        Label {
            Text("목소리 자체는 Supertonic3가 만들고, 뽀글뽀글 말하기는 말하기 질감을 보정하는 효과로 유지합니다.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "flask.fill")
                .foregroundStyle(.blue)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $experimentalEnabled) {
                Label("Supertonic3 활성화", systemImage: "slider.horizontal.3")
            }
            .toggleStyle(.switch)
            .disabled(!TTSProductPolicy.labOnlyEnabled)

            Text("고지 수락, 로컬 모델, ONNX Runtime이 모두 준비된 경우에만 실제 합성으로 연결됩니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $useBubbleSpeechEffect) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("뽀글뽀글 말하기", systemImage: "waveform.path")
                    Text("BubbleSpeech 효과")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
            statusPill("로컬 모델", Supertonic3ModelLocator.isModelAvailable() ? "있음" : "없음")
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

            Picker("뽀글말하기 톤", selection: $bubbleSpeechProfile) {
                ForEach(BubbleSpeechVoiceProfile.allCases) { profile in
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
                    Label("Supertonic3 미리듣기", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canRunPreview || isPreviewing)

                Button {
                    runBubbleSpeechPreview()
                } label: {
                    Label("뽀글뽀글 미리듣기", systemImage: "waveform")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canRunBubbleSpeechEffect || !useBubbleSpeechEffect || isPreviewing)

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

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(previewStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup(isExpanded: $showDiagnostics) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("전처리 출력")
                        .font(.caption.weight(.semibold))
                    Text(processedText)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.top, 6)
            } label: {
                Label("진단 보기", systemImage: "stethoscope")
                    .font(.caption.weight(.semibold))
            }
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
            previewStatus = "Supertonic3 미리듣기 조건이 아직 충족되지 않았습니다. 활성화, 고지 수락, 로컬 모델, ONNX Runtime을 확인하세요."
            return
        }
        isPreviewing = true
        previewStatus = "합성 요청 중..."
        Task {
            let output = await SpeechManager.shared.previewWithTuning(
                text: sampleText,
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
                    previewStatus = "Supertonic3 캐릭터 TTS 미리듣기를 재생했습니다."
                } else {
                    previewStatus = "합성 런타임이 응답하지 않았습니다. 캐릭터 TTS는 성공 처리하지 않았습니다."
                }
            }
        }
    }

    private func runBubbleSpeechPreview() {
        guard noticeAccepted else {
            previewStatus = "고지 수락 후 뽀글뽀글 말하기 효과를 실행할 수 있습니다."
            return
        }
        guard canRunBubbleSpeechEffect else {
            previewStatus = "Supertonic3 캐릭터 목소리 합성 조건이 아직 충족되지 않아 뽀글뽀글 말하기를 만들 수 없습니다."
            return
        }
        isPreviewing = true
        previewStatus = "Supertonic3 캐릭터 목소리를 음절 리듬으로 재구성하는 중..."
        Task {
            let duration = await SpeechManager.shared.previewBubbleSpeech(
                text: sampleText,
                preset: selectedProfile.preset,
                profile: bubbleSpeechProfile,
                pitch: Float(tempPitch + Double(selectedProfile.basePitch)),
                rate: Float(tempRate),
                speed: Float(tempSpeed),
                emotion: selectedEmotion,
                agentID: selectedProfile.agentID,
                label: "tts_lab_bubble_speech_effect",
                useExpressionTags: useExpressionTags
            )
            await MainActor.run {
                isPreviewing = false
                if let duration, duration > 0 {
                    previewStatus = "Supertonic3 캐릭터 목소리를 음절 리듬으로 재구성한 뽀글뽀글 말하기를 재생했습니다."
                } else {
                    previewStatus = "뽀글뽀글 말하기 생성에 실패했습니다. Supertonic3 합성 또는 음절 리듬 렌더링이 완료되지 않았습니다."
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
        case .bubbleSpeech: return "뽀글말하기"
        }
    }
}
