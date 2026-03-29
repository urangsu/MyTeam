import SwiftUI
import AppKit

// MARK: - 직업별 대표 프롬프트 프리셋
struct JobPreset: Identifiable {
    let id = UUID()
    let title: String        // 직업 이름
    let icon: String         // SF Symbol
    let defaultPrompt: String // 기본 프롬프트
}

let jobPresets: [JobPreset] = [
    JobPreset(title: "프로젝트 매니저", icon: "chart.bar.doc.horizontal",
              defaultPrompt: "항상 논리적이고 친절하며, 프로젝트의 전체적인 방향성을 제시합니다. 팀원들의 업무를 조율하고 격려하는 말투를 사용하세요."),
    JobPreset(title: "백엔드 개발자", icon: "server.rack",
              defaultPrompt: "기술적인 부분에 민감하며, 코드 품질과 서버 안정성에 대해서는 단호합니다. '데이터'나 '최적화'라는 단어를 즐겨 사용합니다."),
    JobPreset(title: "프론트엔드 개발자", icon: "macwindow",
              defaultPrompt: "최신 웹/앱 기술에 관심이 많고, 사용자 인터페이스의 반응성과 애니메이션에 집착합니다. 효율적이고 빠른 구현을 지향합니다."),
    JobPreset(title: "UI/UX 디자이너", icon: "paintbrush.pointed",
              defaultPrompt: "사용자 경험과 디자인의 아름다움을 중시합니다. 밝고 긍정적이며, '직관적', '심미적'인 관점에서 의견을 냅니다."),
    JobPreset(title: "QA 엔지니어", icon: "checkmark.shield",
              defaultPrompt: "꼼꼼한 성격으로 버그를 찾는 데 천재적이며, 항상 예외 상황을 고려합니다. 조심스럽지만 정확한 말투를 사용합니다."),
    JobPreset(title: "데이터 분석가", icon: "chart.pie",
              defaultPrompt: "수치와 통계를 바탕으로 말하며, 복잡한 데이터를 알기 쉽게 설명하는 것을 좋아합니다. 객관적인 분석을 중시합니다."),
    JobPreset(title: "DevOps 엔지니어", icon: "gearshape.2",
              defaultPrompt: "배포 자동화와 인프라 관리에 해박합니다. 과묵하지만 핵심을 찌르는 말을 합니다."),
    JobPreset(title: "ML 엔지니어", icon: "brain",
              defaultPrompt: "최신 알고리즘과 모델 학습에 열정적입니다. 미래 지향적인 관점에서 이야기합니다."),
    JobPreset(title: "마케터", icon: "megaphone",
              defaultPrompt: "트렌드에 민감하고 소비자 심리를 잘 파악합니다. 성과 지표(KPI)를 중시하며 긍정적이고 열정적인 말투를 사용합니다."),
    JobPreset(title: "CEO/창업자", icon: "building.2",
              defaultPrompt: "사업 전체를 조망하며 비전과 전략을 이야기합니다. 결단력이 있고 큰 그림을 그리면서도 실행력을 강조합니다."),
    JobPreset(title: "고객 지원", icon: "person.crop.circle.badge.questionmark",
              defaultPrompt: "항상 친절하고 공감하는 말투를 사용합니다. 고객의 문제를 빠르게 파악하고 해결책을 제시하는 데 집중합니다."),
    JobPreset(title: "콘텐츠 크리에이터", icon: "video",
              defaultPrompt: "창의적이고 트렌디한 콘텐츠를 기획합니다. 재미있는 표현을 좋아하고 대중의 관심을 끄는 방법을 잘 알고 있습니다."),
    JobPreset(title: "비서/어시스턴트", icon: "calendar.badge.clock",
              defaultPrompt: "일정 관리와 할 일 정리에 능숙합니다. 정중하고 꼼꼼하며, 상대방의 시간을 소중히 여깁니다. 항상 한 발 앞서 준비합니다."),
    JobPreset(title: "보안 전문가", icon: "lock.shield",
              defaultPrompt: "보안 위협과 취약점에 매우 민감합니다. 신중하고 경계심이 강하며, 모든 것을 의심하는 습관이 있습니다."),
]

struct AgentSettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager
    let config: AgentWindowManager.AgentConfig
    let onClose: () -> Void

    // 이 에이전트의 맞춤 성격을 저장할 AppStorage
    @AppStorage var customPersona: String
    @AppStorage var selectedJob: String  // 선택된 직업 프리셋 이름

    // UI 상태
    @State private var inputText: String = ""
    @State private var showPresets: Bool = false

    init(config: AgentWindowManager.AgentConfig, onClose: @escaping () -> Void) {
        self.config = config
        self.onClose = onClose
        self._customPersona = AppStorage(wrappedValue: "", "custom_persona_\(config.id)")
        self._selectedJob = AppStorage(wrappedValue: config.role, "custom_job_\(config.id)")
    }

    var body: some View {
        let bgColor = manager.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(red: 0.95, green: 0.95, blue: 0.97)
        let textColor = manager.isDarkMode ? Color.white : Color.black
        let subTextColor = manager.isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6)

        VStack(spacing: 0) {
            // 상단 타이틀 바
            HStack {
                Text(config.emoji).font(.system(size: 20))
                Text("\(config.name) 추가 설정")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textColor)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(subTextColor)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bgColor)

            Divider().background(textColor.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ── 직업 선택 프리셋 ──
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("직업 프리셋")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(textColor)
                            Spacer()
                            Button(action: { withAnimation { showPresets.toggle() } }) {
                                HStack(spacing: 4) {
                                    Text(selectedJob)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(config.color)
                                    Image(systemName: showPresets ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9))
                                        .foregroundColor(subTextColor)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 8).fill(config.color.opacity(0.1)))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Text("직업을 선택하면 기본 프롬프트가 자동 적용됩니다.")
                            .font(.system(size: 10))
                            .foregroundColor(subTextColor.opacity(0.7))

                        if showPresets {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(jobPresets) { preset in
                                    Button(action: {
                                        selectedJob = preset.title
                                        inputText = preset.defaultPrompt
                                        withAnimation { showPresets = false }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: preset.icon)
                                                .font(.system(size: 12))
                                                .foregroundColor(selectedJob == preset.title ? .white : config.color)
                                            Text(preset.title)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(selectedJob == preset.title ? .white : textColor)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8).padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedJob == preset.title ? config.color : (manager.isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    Divider().background(textColor.opacity(0.08))

                    // ── 세부 성격 설정 (커스텀) ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("세부 성격 설정")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(textColor)
                        Text("에이전트에게 특별히 지시할 성격이나 말투를 적어주세요.\n프리셋 위에 추가로 적용됩니다.")
                            .font(.system(size: 11))
                            .foregroundColor(subTextColor)
                            .fixedSize(horizontal: false, vertical: true)

                        TextEditor(text: $inputText)
                            .font(.system(size: 13))
                            .foregroundColor(textColor)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(manager.isDarkMode ? Color.black.opacity(0.3) : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(textColor.opacity(0.1), lineWidth: 1)
                            )
                            .frame(height: 120)
                    }

                    // 저장 버튼
                    Button(action: {
                        self.customPersona = self.inputText
                        print("[\(config.name)] 직업: \(selectedJob), 커스텀 성격 저장 완료")
                        onClose()
                    }) {
                        Text("저장하기")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(config.color)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(20)
            }
            .background(bgColor)
        }
        .frame(width: 360, height: 520)
        .cornerRadius(16)
        .onAppear {
            self.inputText = self.customPersona
        }
    }
}
