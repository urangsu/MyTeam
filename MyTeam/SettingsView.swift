import SwiftUI
import AppKit
import CoreLocation

// MARK: - SettingsView
// 환경 설정 창 (API 키 입력 등)
struct SettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager
    var onClose: (() -> Void)? = nil
    @State private var locationLoading: Bool = false
    
    // 3개 API 제공자 영구 저장 (보안을 위해 Keychain 사용)
    @State private var geminiAPIKey: String = ""
    @State private var claudeAPIKey: String = ""
    @State private var openaiAPIKey: String = ""

    // 사용자 설정
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userTitle") private var userTitle: String = "사용자님"
    @AppStorage("agentWindowOpacity") private var agentWindowOpacity: Double = 0.0
    @AppStorage("teamName") private var teamName: String = "MyTeam"
    @AppStorage("showTeamName") private var showTeamName: Bool = true
    @AppStorage("teamNameColor") private var teamNameColor: String = "#FFFFFF"
    @AppStorage("useCloudVoice") private var useCloudVoice: Bool = false
    @AppStorage("useAnimalTTS") private var useAnimalTTS: Bool = true
    @AppStorage("appLanguage") private var appLanguage: String = "한국어"
    @AppStorage("userLocation") private var userLocation: String = "서울"

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

                    // 사용자 이름 + 호칭 (한 줄)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("이름")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(textColor.opacity(0.8))
                                TextField("홍길동", text: $userName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 13))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("호칭")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(textColor.opacity(0.8))
                                TextField("대표님", text: $userTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 13))
                            }
                        }
                        Text("에이전트가 맥락에 따라 이름과 호칭을 유기적으로 사용합니다")
                            .font(.system(size: 10))
                            .foregroundColor(textColor.opacity(0.4))
                    }

                    // 현재 위치
                    VStack(alignment: .leading, spacing: 4) {
                        Text("현재 위치 / 지역")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(textColor.opacity(0.8))
                        HStack(spacing: 6) {
                            TextField("어디에 계신가요?", text: $userLocation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                            Button(action: { requestGPSLocation() }) {
                                Image(systemName: locationLoading ? "arrow.triangle.2.circlepath" : "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 22)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("GPS로 현재 위치 자동 입력")
                        }
                        Text("에이전트가 현실적인 대화를 하기 위해 참고합니다")
                            .font(.system(size: 10))
                            .foregroundColor(textColor.opacity(0.4))
                    }

                    // 언어 설정
                    VStack(alignment: .leading, spacing: 4) {
                        Text("대화 언어 (App Language)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(textColor.opacity(0.8))
                        Picker("", selection: $appLanguage) {
                            Text("한국어").tag("한국어")
                            Text("English").tag("English")
                            Text("日本語").tag("日本語")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        Text("에이전트들이 대답할 주 언어를 선택하세요.")
                            .font(.system(size: 10))
                            .foregroundColor(textColor.opacity(0.4))
                    }

                    // 팀 명칭
                    VStack(alignment: .leading, spacing: 6) {
                        Text("팀 명칭")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(textColor.opacity(0.8))
                        HStack(spacing: 8) {
                            TextField("MyTeam", text: $teamName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                            
                            // HEX 필드 (클릭 시 컬러 피커 열림)
                            TextField("#FFFFFF", text: $teamNameColor)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 75)
                                .onTapGesture {
                                    let panel = NSColorPanel.shared
                                    panel.color = NSColor(Color(hex: teamNameColor) ?? .white)
                                    panel.isContinuous = true
                                    panel.makeKeyAndOrderFront(nil)
                                }
                            
                            Toggle("표시", isOn: $showTeamName)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                        }
                        Text("메인 창 상단에 표시되는 팀 이름의 배경 색상을 선택할 수 있습니다.")
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
                            Text("🐾 동물 TTS")
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

                // ── 팀원창 설정 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("팀원창")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)

                    // 배경 투명도
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("배경 투명도")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(textColor.opacity(0.8))
                            Spacer()
                            Text("\(Int(agentWindowOpacity * 100))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(textColor.opacity(0.6))
                        }
                        Slider(value: $agentWindowOpacity, in: 0.0...1.0, step: 0.05)
                            .tint(.blue)
                        Text("에이전트 팀원창의 배경 불투명도를 조절합니다")
                            .font(.system(size: 10))
                            .foregroundColor(textColor.opacity(0.4))
                    }
                }

                Divider().background(textColor.opacity(0.1)).padding(.vertical, 4)

                // ── 윈도우 정돈 ──
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("대화창 정돈 📑")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textColor)
                        
                        Spacer()
                        
                        Button(action: {
                            manager.arrangeWindows()
                            onClose?()
                        }) {
                            Text("정돈")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
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
                        let text = cheers.randomElement()!
                        let agents = manager.activeAgents
                        let agent = agents.randomElement() ?? agents[0]
                        manager.addChatLog(agentID: agent.id, agentName: agent.name, text: text, isUser: false)
                        if !manager.isSilentMode { SpeechManager.shared.speak(text: text) }
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
                        KeychainManager.save(key: "geminiAPIKey", value: geminiAPIKey)
                        KeychainManager.save(key: "claudeAPIKey", value: claudeAPIKey)
                        KeychainManager.save(key: "openaiAPIKey", value: openaiAPIKey)
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
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(textColor.opacity(0.1), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.2), radius: 10)
        )
        .onAppear {
            geminiAPIKey = KeychainManager.load(key: "geminiAPIKey")
            claudeAPIKey = KeychainManager.load(key: "claudeAPIKey")
            openaiAPIKey = KeychainManager.load(key: "openaiAPIKey")
            
            // 컬러 피커가 임사적으로 열려있는 경우 닫기 (요청 사항: 키자마자 나오지 않게)
            NSColorPanel.shared.close()
        }
        // 컬러 피퍼에서 색상 선택 시 teamNameColor 업데이트
        .onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)) { _ in
            let selectedColor = Color(NSColorPanel.shared.color)
            if let hex = selectedColor.toHex() {
                self.teamNameColor = hex
            }
        }
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

    // MARK: - GPS 위치 자동 감지
    private func requestGPSLocation() {
        locationLoading = true
        let locator = GPSLocator()
        locator.requestLocation { result in
            DispatchQueue.main.async {
                locationLoading = false
                switch result {
                case .success(let placeName):
                    userLocation = placeName
                case .failure(let error):
                    print("[Settings] GPS 실패: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - GPS Helper
private class GPSLocator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Result<String, Error>) -> Void)?

    func requestLocation(completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            completion(.failure(NSError(domain: "GPS", code: -1, userInfo: [NSLocalizedDescriptionKey: "위치 권한이 거부되었습니다. 시스템 설정에서 허용해주세요."])))
        } else {
            // .notDetermined일 때 startUpdatingLocation 호출하면 자동으로 권한 팝업 표시
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // CLGeocoder: macOS 26에서 deprecated 예정이나 현재 macOS 15 호환 필요
        let geocoder: CLGeocoder = {
            if #available(macOS 26, *) { /* TODO: MKReverseGeocodingRequest로 전환 */ }
            return CLGeocoder()
        }()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                self?.completion?(.failure(error))
                return
            }
            guard let place = placemarks?.first else {
                self?.completion?(.failure(NSError(domain: "GPS", code: -2, userInfo: [NSLocalizedDescriptionKey: "주소를 찾을 수 없습니다."])))
                return
            }
            let admin = place.administrativeArea ?? ""
            let locality = place.locality ?? place.subAdministrativeArea ?? ""
            let name = [admin, locality].filter { !$0.isEmpty }.joined(separator: " ")
            self?.completion?(.success(name.isEmpty ? "알 수 없음" : name))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(.failure(error))
    }
}
