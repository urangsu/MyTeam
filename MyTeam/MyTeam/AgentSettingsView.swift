import SwiftUI
import AppKit

struct AgentSettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager
    let config: AgentWindowManager.AgentConfig
    let onClose: () -> Void
    
    // 이 에이전트의 맞춤 성격을 저장할 AppStorage
    @AppStorage var customPersona: String
    
    // 역할 / 직업 커스텀 설정
    @AppStorage var customRole: String
    @AppStorage var customJob: String
    
    // UI 상태 조작을 위한 내부 텍스트 변수
    @State private var inputText: String = ""
    @State private var inputRole: String = ""
    @State private var inputJob: String = ""
    
    init(config: AgentWindowManager.AgentConfig, onClose: @escaping () -> Void) {
        self.config = config
        self.onClose = onClose
        // 동적 AppStorage 키 할당
        self._customPersona = AppStorage(wrappedValue: "", "custom_persona_\(config.id)")
        self._customRole = AppStorage(wrappedValue: config.role, "custom_role_\(config.id)")
        self._customJob = AppStorage(wrappedValue: "", "custom_job_\(config.id)")
    }
    
    var body: some View {
        let bgColor = manager.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(red: 0.95, green: 0.95, blue: 0.97)
        let textColor = manager.isDarkMode ? Color.white : Color.black
        let subTextColor = manager.isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
        let fieldBg = manager.isDarkMode ? Color.black.opacity(0.3) : Color.white
        
        VStack(spacing: 0) {
            // ── 상단 타이틀 바 ──
            HStack {
                Text(config.emoji)
                    .font(.system(size: 20))
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
            
            // ── 입력 폼 영역 ──
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // ─ 역할 입력 (상단 첫 번째) ─
                    VStack(alignment: .leading, spacing: 6) {
                        Label("역할", systemImage: "person.text.rectangle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(subTextColor)
                        TextField("예: 프로젝트 매니저, 백엔드 개발자...", text: $inputRole)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .foregroundColor(textColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(fieldBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(textColor.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // ─ 직업/전문분야 입력 (두 번째) ─
                    VStack(alignment: .leading, spacing: 6) {
                        Label("전문 분야 / 직업", systemImage: "briefcase")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(subTextColor)
                        TextField("예: iOS 개발, 데이터 분석, UX 리서치...", text: $inputJob)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .foregroundColor(textColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(fieldBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(textColor.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    Divider().background(textColor.opacity(0.08))
                    
                    // ─ 성격/말투 입력 (기존, 세 번째) ─
                    VStack(alignment: .leading, spacing: 6) {
                        Label("성격 / 말투", systemImage: "quote.bubble")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(subTextColor)
                        Text("에이전트에게 특별히 지시할 성격이나 말투를 적어주세요.\n(예: 항상 반말로 대답해, 말끝마다 멍멍이라고 붙여 등)")
                            .font(.system(size: 11))
                            .foregroundColor(subTextColor.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        TextEditor(text: $inputText)
                            .font(.system(size: 14))
                            .foregroundColor(textColor)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(fieldBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(textColor.opacity(0.1), lineWidth: 1)
                            )
                            .frame(height: 120)
                    }
                    
                    // ─ 저장 버튼 ─
                    Button(action: {
                        self.customPersona = self.inputText
                        self.customRole = self.inputRole
                        self.customJob = self.inputJob
                        print("[\(config.name)] 설정 저장 완료 - 역할: \(customRole), 직업: \(customJob)")
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
        .frame(width: 360, height: 480) // 역할/직업 입력란 추가로 높이 확대
        .cornerRadius(16)
        .onAppear {
            self.inputText = self.customPersona
            self.inputRole = self.customRole
            self.inputJob = self.customJob
        }
    }
}
