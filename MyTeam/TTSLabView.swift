import SwiftUI

struct TTSLabView: View {
    @AppStorage("supertonic3ExperimentalEnabled") private var experimentalEnabled: Bool = false
    @AppStorage("useAnimalCrossingTTS") private var useAnimaleseEffect: Bool = false

    @State private var selectedProfileID: String = CharacterVoiceProfileCatalog.profiles.first?.id ?? ""
    @State private var selectedEmotion: SupertonicEmotionStyle = .friendly
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
        experimentalEnabled && noticeAccepted && !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            Text("캐릭터별 목소리 톤, 속도, 전처리 결과를 좁은 설정창 안에서 확인합니다.")
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

            Toggle(isOn: $useAnimaleseEffect) {
                Label("동물의숲 효과 연구", systemImage: "sparkles")
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
            statusPill("제품 노출", TTSProductPolicy.canShipAsProductFeature ? "가능" : "보류")
            statusPill("런타임", TTSRoutingPolicy.isSupertonic3Available ? "사용 가능" : "비활성")
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
                    Label("미리듣기", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canRunPreview || isPreviewing)

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
            previewStatus = "고지 수락 후 미리듣기를 실행할 수 있습니다."
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
                    previewStatus = "미리듣기를 실행했습니다."
                } else {
                    previewStatus = "현재 합성 런타임이 비활성이라 오디오는 생성되지 않았습니다."
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
