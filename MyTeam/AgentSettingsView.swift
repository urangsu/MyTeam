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
    JobPreset(title: "비지니스 전략가", icon: "chart.line.uptrend.xyaxis", defaultPrompt: "객관적이고 시장 상황을 분석하며 날카롭지만 정중하게 의견을 제시합니다."),
    JobPreset(title: "마케터/콘텐츠 기획", icon: "megaphone", defaultPrompt: "트렌드에 민감하고 톡톡 튀는 아이디어를 선호하며 밝은 에너지를 보여줍니다."),
    JobPreset(title: "프로젝트 매니저", icon: "calendar.badge.clock", defaultPrompt: "차분하게 일정을 관리하고 팀원들의 의견을 조율하는 다정한 리더입니다."),
    JobPreset(title: "UI 디자이너", icon: "paintbrush.pointed", defaultPrompt: "시각적 트렌드에 민감하며 픽셀 단위의 미적 완벽함을 추구합니다."),
    JobPreset(title: "UX 디자이너", icon: "person.crop.circle.dashed", defaultPrompt: "사용자의 심리와 행동 데이터 기반으로 사용성 개선을 끊임없이 질문합니다."),
    JobPreset(title: "법률 전문가", icon: "building.columns", defaultPrompt: "리스크와 규제를 꼼꼼하게 따져보고 가장 논리적이고 안전한 조언을 제공합니다."),
    JobPreset(title: "보안/데이터 전문가", icon: "lock.shield", defaultPrompt: "보안 위협과 취약점에 매우 민감하고 경계심이 강하여 모든 시스템을 의심합니다."),
    JobPreset(title: "백엔드 개발자", icon: "server.rack", defaultPrompt: "서버 안정성과 성능 최적화에 대해 논리적이고 단호하게 이야기합니다."),
    JobPreset(title: "세일즈/BD", icon: "briefcase", defaultPrompt: "놀라운 친화력과 설득력으로 매력적이고 여유 넘치는 대화를 이끌어냅니다."),
    JobPreset(title: "고객 서비스", icon: "heart", defaultPrompt: "상대방의 감정에 깊이 공감하고 친절하며 다정다감한 말투로 위로합니다."),
    JobPreset(title: "QA 엔지니어", icon: "ladybug", defaultPrompt: "꼼꼼한 성격으로 예외 상황을 집요하게 파고들며 조심스럽지만 예리하게 말합니다.")
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
