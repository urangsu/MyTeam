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

    // 사용자 설정
    @AppStorage("userTitle") private var userTitle: String = "사용자님"
    @AppStorage("teamName") private var teamName: String = "MyTeam"
    @AppStorage("showTeamName") private var showTeamName: Bool = true
    @AppStorage("useCloudVoice") private var useCloudVoice: Bool = false
    @AppStorage("useAnimalTTS") private var useAnimalTTS: Bool = true

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
                

                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)

                // ── 사용자 설정 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("사용자 설정")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)

                    // 사용자 호칭
                    VStack(alignment: .leading, spacing: 4) {
                        Text("사용자 호칭")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(textColor.opacity(0.8))
                        TextField("사용자님", text: $userTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13))
                        Text("에이전트가 나를 부를 때 사용합니다 (예: 사용자님, 대표님, 이름)")
                            .font(.system(size: 10))
                            .foregroundColor(textColor.opacity(0.4))
                    }

                    // 팀 명칭
                    VStack(alignment: .leading, spacing: 4) {
                        Text("팀 명칭")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(textColor.opacity(0.8))
                        HStack {
                            TextField("MyTeam", text: $teamName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                            Toggle("표시", isOn: $showTeamName)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                                .help(showTeamName ? "팀 명칭 표시 중" : "팀 명칭 숨김")
                        }
                        Text("메인 창 상단에 표시되는 팀 이름")
                            .font(.system(size: 10))
                            .foregroundColor(textColor.opacity(0.4))
                    }
                }

                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)

                // ── 음성 / TTS 설정 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("음성 설정")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)

                    // 동물의 숲 TTS
                    Toggle(isOn: $useAnimalTTS) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🐾 기본 TTS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(textColor)
                            Text("팀원의 말소리를 귀여운 로컬 스타일로 재생")
                                .font(.system(size: 10))
                                .foregroundColor(textColor.opacity(0.45))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .onChange(of: useAnimalTTS) { _, newValue in
                        // 꺼질 때 재생 중인 AnimalTTS 즉시 중단
                        if !newValue { AnimalTTSManager.shared.stop() }
                    }

                    // 클라우드 TTS (useAnimalTTS가 꺼져 있을 때만 의미 있음)
                    Toggle(isOn: $useCloudVoice) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("클라우드 TTS 사용")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(useAnimalTTS ? textColor.opacity(0.35) : textColor)
                            Text("백엔드에서 생성한 고품질 음성 사용 (네트워크 필요)")
                                .font(.system(size: 10))
                                .foregroundColor(textColor.opacity(0.45))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .disabled(useAnimalTTS)  // 동물의 숲 TTS 켜져 있으면 비활성화
                }

                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)

                // ── 응원받기 ──
                VStack(alignment: .leading, spacing: 10) {
                    Text("응원받기 🎉")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                    Text("에이전트에게 지금 바로 응원 한마디를 요청합니다.")
                        .font(.system(size: 11))
                        .foregroundColor(textColor.opacity(0.5))
                    Button(action: {
                        let cheers = [
                            "지금 정말 잘하고 계세요! 조금만 더 힘내세요!",
                            "오늘 하루도 멋지게 해내고 있어요! 최고예요!",
                            "당신이 있어서 우리 팀이 빛나요! 파이팅!",
                            "한 걸음씩 가다 보면 목표에 도달해요. 믿고 있어요!",
                            "이렇게까지 열심히 하시는 분 처음 봤어요. 정말 대단해요!"
                        ]
                        WebSocketClient.shared.sendSystemEvent(
                            eventType: "cheer",
                            baseGreeting: cheers.randomElement()!
                        )
                        onClose?()
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("응원 한마디 받기")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                        ))
                    }
                    .buttonStyle(PlainButtonStyle())
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
        .frame(width: 440, height: 700)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(textColor.opacity(0.1), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.2), radius: 10)
        )
    }
    
    // MARK: - API 키 검증 (로컬 직접 호출 — 서버 불필요)
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

        Task {
            do {
                let result = try await AIService.shared.validateKey(
                    provider: validationProvider,
                    apiKey: keyToValidate
                )
                await MainActor.run {
                    self.validationMessage = "✅ \(result)"
                    self.isValidating = false
                }
            } catch {
                await MainActor.run {
                    self.validationMessage = "❌ \(error.localizedDescription)"
                    self.isValidating = false
                }
            }
        }
    }
}
