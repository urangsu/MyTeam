import SwiftUI
import AppKit

struct AgentSettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager
    let config: AgentWindowManager.AgentConfig
    let onClose: () -> Void
    
    // 이 에이전트의 맞춤 성격을 저장할 AppStorage
    @AppStorage var customPersona: String
    
    // UI 상태 조작을 위한 내부 텍스트 변수
    @State private var inputText: String = ""
    
    init(config: AgentWindowManager.AgentConfig, onClose: @escaping () -> Void) {
        self.config = config
        self.onClose = onClose
        // 동적 AppStorage 키 할당 (예: "custom_persona_agent_1")
        self._customPersona = AppStorage(wrappedValue: "", "custom_persona_\(config.id)")
    }
    
    var body: some View {
        let bgColor = manager.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(red: 0.95, green: 0.95, blue: 0.97)
        let textColor = manager.isDarkMode ? Color.white : Color.black
        let subTextColor = manager.isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
        
        VStack(spacing: 0) {
            // 상단 타이틀 바
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
            
            // 입력 폼 영역
            VStack(alignment: .leading, spacing: 16) {
                Text("에이전트에게 특별히 지시할 성격이나 말투를 적어주세요.\n(예: 항상 반말로 대답해, 말끝마다 멍멍이라고 붙여 등)")
                    .font(.system(size: 13))
                    .foregroundColor(subTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                
                TextEditor(text: $inputText)
                    .font(.system(size: 14))
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
                    .frame(height: 150)
                
                Spacer()
                
                // 저장 버튼
                Button(action: {
                    self.customPersona = self.inputText
                    print("[\(config.name)] 커스텀 성격 저장 완료: \(self.customPersona)")
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
            .background(bgColor)
        }
        .frame(width: 320, height: 360)
        .cornerRadius(16)
        .onAppear {
            self.inputText = self.customPersona
        }
    }
}
