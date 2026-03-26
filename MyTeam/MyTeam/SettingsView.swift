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
                
                Spacer(minLength: 20)
                
                // ── 하단 버튼 ──
                HStack {
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
        }
        .frame(width: 440, height: 500)
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
