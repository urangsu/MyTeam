import SwiftUI
import AppKit

// MARK: - SettingsView
// 환경 설정 창 (API 키 입력 등)
struct SettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager
    var onClose: (() -> Void)? = nil
    
    // 3개 API 제공자 영구 저장
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @AppStorage("claudeAPIKey") private var claudeAPIKey: String = ""
    @AppStorage("openaiAPIKey") private var openaiAPIKey: String = ""
    
    // 검증을 위해 선택할 제공자 저장
    @AppStorage("validationProvider") private var validationProvider: String = "Gemini"
    @AppStorage("customBackendURL") private var customBackendURL: String = "ws://127.0.0.1:8000/ws"
    
    // 오디오 하이브리드 세팅
    @AppStorage("useCloudVoice") private var useCloudVoice: Bool = false
    
    // 사용자 하칭
    @AppStorage("userTitle") private var userTitle: String = "사용자님"
    
    // 팀 명칭
    @AppStorage("teamName") private var teamName: String = "MyTeam"
    @AppStorage("showTeamName") private var showTeamName: Bool = true
    
    let providers = ["Gemini", "Claude", "OpenAI"]
    
    // 키 검증 상태
    @State private var validationMessage: String = ""
    @State private var isValidating: Bool = false
    
    var body: some View {
        let isDarkMode = manager.isDarkMode
        let bgColor = isDarkMode ? Color(red: 0.1, green: 0.1, blue: 0.15) : Color.white
        let textColor = isDarkMode ? Color.white : Color.black
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // ── 상단 타이틀 및 닫기 버튼 ──
                HStack {
                    Text("설정")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(textColor)
                    
                    Spacer()
                    
                    // 닫기 버튼 (X)
                    Button(action: {
                        onClose?()
                    }) {
                        ZStack {
                            Circle()
                                .fill(textColor.opacity(0.1))
                                .frame(width: 28, height: 28)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(textColor.opacity(0.8))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("닫기")
                }
                .padding(.bottom, 8)
                
                // ── API 키 입력 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("API 키 연동 (다중 사용 가능)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                    
                    // Gemini
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gemini API Key").font(.system(size: 11, weight: .bold)).foregroundColor(textColor.opacity(0.8))
                        SecureField("AI Studio Key", text: $geminiAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                    }
                    
                    // Claude
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Claude API Key").font(.system(size: 11, weight: .bold)).foregroundColor(textColor.opacity(0.8))
                        SecureField("sk-ant-...", text: $claudeAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                    }
                    
                    // OpenAI
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenAI API Key").font(.system(size: 11, weight: .bold)).foregroundColor(textColor.opacity(0.8))
                        SecureField("sk-proj-...", text: $openaiAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                
                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)
                
                // ── API 키 검증 (단일 선택) ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("API 통신 검증")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                    
                    Picker("", selection: $validationProvider) {
                        ForEach(providers, id: \.self) { provider in
                            Text(provider).tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack(spacing: 12) {
                        Button(action: validateAPIKey) {
                            HStack {
                                if isValidating {
                                    ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                }
                                Text("\(validationProvider) 통신 확인")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.8)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(validationMessage)
                            .font(.system(size: 11))
                            .foregroundColor(validationMessage.contains("성공") ? .green : .red)
                    }
                }
                
                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)
                
                // ── 백엔드 URL ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("백엔드 서버 URL")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                    
                    TextField("ws://", text: $customBackendURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))
                }
                
                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)
                
                // ── 사용자 호칭 설정 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("사용자 호칭 (AI 에이전트가 부를 이름)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                    
                    TextField("예: 사용자님, 보스, 매니저 등", text: $userTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 13))
                }
                
                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)
                
                // ── 팀 명칭 설정 ──
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("팀 명칭 (1~8글자)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textColor)
                        Spacer()
                        Toggle("화면 표시", isOn: $showTeamName)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .font(.system(size: 11))
                    }
                    TextField("팀 이름 (최대 8글자)", text: Binding(
                        get: { teamName },
                        set: { newValue in
                            let filtered = String(newValue.prefix(8))
                            teamName = filtered
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 13))
                    Text("팔원들 위에 표시되며 클릭 시 팀 전체를 드래그할 수 있습니다.")
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("음성 상호작용 (TTS / STT)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                    
                    Toggle("고품질 클라우드 음성 사용 (OpenAI 등 API 소모)", isOn: $useCloudVoice)
                        .font(.system(size: 12))
                        .foregroundColor(textColor.opacity(0.9))
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Text("체크 해제 시 맥북 내장 시스템(무료) 목소리나 커스텀 파일로 우회합니다.")
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.5))
                        .padding(.top, -6)
                    
                    Button(action: {
                        // 커스텀 음성 폴더 열기 (추후 로컬 연동)
                        print("커스텀 보이스 폴더 열기")
                    }) {
                        HStack {
                            Image(systemName: "folder.fill").foregroundColor(.orange)
                            Text("커스텀 에이전트 보이스 폴더 열기")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(textColor.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(textColor.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer(minLength: 20)
                
                // ── 하단 버튼 ──
                HStack {
                    Button(action: {
                        WebSocketClient.shared.sendSystemEvent(eventType: "shutdown", baseGreeting: "사용자님, 오늘 정말 고생 많으셨어요. 푹 쉬세요!")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            NSApplication.shared.terminate(nil)
                        }
                    }) {
                        Text("앱 종료하기")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.8)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        let cheerGreetings = [
                            "사용자님, 지금 최고예요! 제가 항상 뒤에 있는 거 아시죠?",
                            "사용자님, 지금 페이스 너무 좋아요! 역시 우리 팀의 핵심이라니까요.",
                            "어려운 문제도 사용자님이라면 금방 해결할 거예요. 제가 응원할게요!",
                            "사용자님, 잠깐 기지개라도 켜세요! 항상 지켜보고 있으니까 힘내요!",
                            "역시 사용자님! 이런 아이디어는 어디서 나오는 거예요? 진짜 대단해요.",
                            "사용자님 곁엔 저희가 있잖아요. 힘들면 언제든 저희를 부려 먹으세요!",
                            "와, 사용자님 방금 작업 속도 대박! 이대로만 쭉쭉 가시죠!",
                            "사용자님은 하면 다 되더라고요. 지금까지 잘해왔으니까 걱정 마세요.",
                            "사용자님, 오늘도 열일하는 모습 너무 멋있어요! 완전 반하겠는데요?",
                            "기운 내세요, 사용자님! 제가 사용자님 제일 믿는 거 아시죠? 화이팅!",
                            "오늘 날씨만큼이나 사용자님 컨디션도 좋아 보여서 다행이에요. 고고!"
                        ]
                        WebSocketClient.shared.sendSystemEvent(eventType: "cheer", baseGreeting: cheerGreetings.randomElement()!)
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("팀원들 응원받기")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.8)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 8)

                    Spacer()
                    Button(action: {
                        WebSocketClient.shared.sendAPIKey() // 새로 입력한 3개 키 모두 전송
                        onClose?()
                    }) {
                        Text(onClose == nil ? "저장" : "저장 및 닫기")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(24)
            .textSelection(.enabled)
        }
        .frame(width: 440, height: 740)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(textColor.opacity(0.1), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.2), radius: 10)
        )
    }
    
    // MARK: - API 키 검증 요청 로직
    private func validateAPIKey() {
        let keyToValidate: String
        switch validationProvider {
        case "Claude": keyToValidate = claudeAPIKey
        case "OpenAI": keyToValidate = openaiAPIKey
        default: keyToValidate = geminiAPIKey
        }
        
        guard !keyToValidate.isEmpty else {
            validationMessage = "❌ [\(validationProvider)] 키를 먼저 입력해주세요."
            return
        }
        
        isValidating = true
        validationMessage = "검증 중..."
        
        // http URL
        let httpUrlString = customBackendURL.replacingOccurrences(of: "ws://", with: "http://").replacingOccurrences(of: "/ws", with: "/validate_key")
        guard let url = URL(string: httpUrlString) else {
            validationMessage = "❌ 잘못된 백엔드 URL"
            isValidating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = [
            "provider": validationProvider,
            "api_key": keyToValidate
        ]
        
        guard let httpBody = try? JSONEncoder().encode(payload) else { return }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isValidating = false
                
                if error != nil {
                    self.validationMessage = "❌ 서버 연결 실패 (파이썬 확인)"
                    return
                }
                
                guard let data = data else {
                    self.validationMessage = "❌ 데이터 없음"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let message = json["message"] as? String {
                        self.validationMessage = message
                    } else {
                        self.validationMessage = "❌ 알 수 없는 응답 형식"
                    }
                } catch {
                    self.validationMessage = "❌ json 해석 오류"
                }
            }
        }.resume()
    }
}
