import SwiftUI
import AppKit
import Combine
@preconcurrency import CoreLocation
import MapKit

// MARK: - 검증 상태
private enum ValidationStatus {
    case idle, loading
    case success(String)
    case failure(String)

    var color: Color {
        switch self {
        case .idle:    return .clear
        case .loading: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }
    var message: String {
        switch self {
        case .idle:            return ""
        case .loading:         return "검증 중..."
        case .success(let m):  return "✅ \(m)"
        case .failure(let m):  return "❌ \(m)"
        }
    }
}

// MARK: - GPS 헬퍼 (CLLocationManager + MKReverseGeocodingRequest)
@MainActor
private class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationText: String = ""
    @Published var isLoading: Bool = false

    private let mgr = CLLocationManager()

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        isLoading = true
        switch mgr.authorizationStatus {
        case .notDetermined:
            mgr.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            mgr.requestLocation()
        default:
            locationText = "위치 권한 없음"
            isLoading = false
        }
    }

    // CLLocationManagerDelegate — 위치 수신 성공
    nonisolated func locationManager(_ manager: CLLocationManager,
                                      didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task {
            do {
                let geocoder = CLGeocoder()
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                if let p = placemarks.first {
                    await MainActor.run {
                        let area = p.administrativeArea ?? ""
                        let city = p.locality ?? ""
                        self.locationText = "\(area) \(city)".trimmingCharacters(in: .whitespaces)
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.locationText = "주소 변환 실패"
                        self.isLoading = false
                    }
                }
            }
        }
    }

    // CLLocationManagerDelegate — 위치 수신 실패
    nonisolated func locationManager(_ manager: CLLocationManager,
                                      didFailWithError error: Error) {
        Task { @MainActor in
            self.locationText = "위치 수신 실패"
            self.isLoading = false
        }
    }

    // CLLocationManagerDelegate — 권한 변경 시 자동 재시도
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = CLLocationManager().authorizationStatus
            if status == .authorizedAlways {
                self.mgr.requestLocation()
            } else if status == .denied || status == .restricted {
                self.locationText = "위치 권한 없음"
                self.isLoading = false
            }
        }
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager

    // ── 사용자 설정
    @AppStorage("userTitle")              private var userTitle: String = "수석님"
    @AppStorage("userLocation")           private var userLocation: String = "전남 광양"
    @AppStorage("teamName")               private var teamName: String = "MyTeam"
    @AppStorage("teamNameColor")          private var teamNameColor: String = "#FFFFFF"
    @AppStorage("agentWindowOpacity")     private var agentWindowOpacity: Double = 0.0
    @AppStorage("useAnimalCrossingTTS")   private var useAnimalCrossingTTS: Bool = true

    // ── API 설정
    @AppStorage("defaultLLMProvider") private var defaultProviderRaw: String = LLMProvider.gemini.rawValue
    @AppStorage("openAIModelId")      private var openAIModelId: String = "gpt-4o"
    @State private var geminiKey: String = ""
    @State private var openAIKey: String = ""
    @State private var claudeKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var openRouterModelId: String = "meta-llama/llama-3-8b-instruct"
    @State private var selectedProvider: LLMProvider = .gemini
    @State private var validationStatus: ValidationStatus = .idle

    @State private var currentTab: Int = 0
    @StateObject private var gps = LocationHelper()

    private var plaqueColor: Binding<Color> {
        Binding(
            get: { Color(hex: teamNameColor) ?? .white },
            set: { teamNameColor = $0.hexString }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 탭 세그먼트 + X 버튼 (같은 라인)
            HStack(spacing: 8) {
                Picker("", selection: $currentTab) {
                    Text("사용자 설정").tag(0)
                    Text("API 설정").tag(1)
                    Text("데스크 라우팅").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button(action: { NSApp.keyWindow?.close() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 26, height: 26)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // ── 탭 콘텐츠
            Group {
                switch currentTab {
                case 0: userSettingsTab
                case 1: apiSettingsTab
                default: deskRoutingTab
                }
            }
        }
        .preferredColorScheme(manager.isDarkMode ? .dark : .light)
        .frame(width: 380, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { loadSettings() }
        .onChange(of: gps.locationText) { _, newVal in
            if !newVal.isEmpty { userLocation = newVal }
        }
    }

    // MARK: - Tab 1: 사용자 설정
    private var userSettingsTab: some View {
        Form {
            Section("기본 정보") {
                LabeledContent {
                    TextField("", text: $userTitle)
                } label: {
                    Label("호칭", systemImage: "person.fill")
                }

                LabeledContent {
                    HStack(spacing: 6) {
                        Button(action: { gps.request() }) {
                            if gps.isLoading {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "location.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20)
                        TextField("", text: $userLocation)
                    }
                } label: {
                    Label("위치", systemImage: "location.fill")
                }
            }

            Section("팀 설정") {
                LabeledContent {
                    HStack(spacing: 6) {
                        TextField("", text: $teamName)
                        ColorPicker("", selection: plaqueColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 36)
                    }
                } label: {
                    Label("팀 이름", systemImage: "flag.fill")
                }
            }

            Section(header: Text("음성"), footer: Text("활성화 시 고품질 음성에 피치와 속도 변조를 덫씌워 캐릭터 느낌을 냅니다.")) {
                Toggle(isOn: $useAnimalCrossingTTS) {
                    Label("동물의숲 효과", systemImage: "waveform")
                }
            }

            Section("팀원창") {
                LabeledContent("투명도 \(Int(agentWindowOpacity * 100))%") {
                    Slider(value: $agentWindowOpacity, in: 0...1.0, step: 0.05)
                        .frame(minWidth: 140)
                }
            }

            Section {
                Button("저장") { saveSettings() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Tab 2: API 설정
    private var apiSettingsTab: some View {
        Form {
            Section("기본 제공자") {
                Picker("제공자", selection: $selectedProvider) {
                    Text("Gemini").tag(LLMProvider.gemini)
                    Text("OpenAI").tag(LLMProvider.openAI)
                    Text("Claude").tag(LLMProvider.claude)
                    Text("OpenRouter").tag(LLMProvider.openRouter)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedProvider) { _, _ in validationStatus = .idle }
            }

            Section("API 키") {
                switch selectedProvider {
                case .gemini:
                    LabeledContent("Gemini Key") {
                        SecureField("", text: $geminiKey)
                    }
                case .openAI:
                    LabeledContent("OpenAI Key") {
                        SecureField("", text: $openAIKey)
                    }
                    LabeledContent("Model ID") {
                        TextField("gpt-4o", text: $openAIModelId)
                    }
                case .claude:
                    LabeledContent("Claude Key") {
                        SecureField("", text: $claudeKey)
                    }
                case .openRouter:
                    LabeledContent("OpenRouter Key") {
                        SecureField("", text: $openRouterKey)
                    }
                    LabeledContent("Model ID") {
                        TextField("meta-llama/llama-3-8b-instruct", text: $openRouterModelId)
                    }
                }

                HStack {
                    if case .loading = validationStatus {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text(validationStatus.message)
                            .font(.caption)
                            .foregroundStyle(validationStatus.color)
                    }
                    Spacer()
                    Button("검증") { validateCurrentKey() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(currentKey(for: selectedProvider).isEmpty)
                }
            }

            Section {
                Button("저장") { saveSettings() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Tab 3: 데스크 라우팅 (4개 데스크)
    private var deskRoutingTab: some View {
        Form {
            ForEach(0..<4, id: \.self) { index in
                Section("데스크 \(index + 1)") {
                    DeskRoutingRow(deskIndex: index)
                }
            }

            Section {
                Button("저장") { saveSettings() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - 내부 로직
    private func currentKey(for provider: LLMProvider) -> String {
        switch provider {
        case .gemini:     return geminiKey
        case .openAI:     return openAIKey
        case .claude:     return claudeKey
        case .openRouter: return openRouterKey
        }
    }

    private func validateCurrentKey() {
        validationStatus = .loading
        let key = currentKey(for: selectedProvider)
        let provider = selectedProvider.rawValue
        Task {
            do {
                let result = try await AIService.shared.validateKey(provider: provider, apiKey: key)
                await MainActor.run { validationStatus = .success(result) }
            } catch {
                await MainActor.run { validationStatus = .failure(error.localizedDescription) }
            }
        }
    }

    private func loadSettings() {
        if let k = KeychainManager.load(key: "geminiAPIKey")     { geminiKey = k }
        if let k = KeychainManager.load(key: "openAIAPIKey")     { openAIKey = k }
        if let k = KeychainManager.load(key: "claudeAPIKey")     { claudeKey = k }
        if let k = KeychainManager.load(key: "openRouterAPIKey") { openRouterKey = k }
        openRouterModelId = UserDefaults.standard.string(forKey: "openRouterModelId")
            ?? "meta-llama/llama-3-8b-instruct"
        if let raw = LLMProvider(rawValue: defaultProviderRaw) { selectedProvider = raw }
    }

    private func saveSettings() {
        KeychainManager.save(key: "geminiAPIKey",     value: geminiKey)
        KeychainManager.save(key: "openAIAPIKey",     value: openAIKey)
        KeychainManager.save(key: "claudeAPIKey",     value: claudeKey)
        KeychainManager.save(key: "openRouterAPIKey", value: openRouterKey)
        UserDefaults.standard.set(openRouterModelId, forKey: "openRouterModelId")
        defaultProviderRaw = selectedProvider.rawValue
    }
}

// MARK: - 데스크 라우팅 행
private struct DeskRoutingRow: View {
    let deskIndex: Int

    @AppStorage private var providerRaw: String
    @AppStorage private var modelId: String

    init(deskIndex: Int) {
        self.deskIndex = deskIndex
        _providerRaw = AppStorage(wrappedValue: LLMProvider.gemini.rawValue,
                                  "llmProvider_desk_\(deskIndex)")
        _modelId     = AppStorage(wrappedValue: "meta-llama/llama-3-8b-instruct",
                                  "openRouterModelId_desk_\(deskIndex)")
    }

    var body: some View {
        LabeledContent("API") {
            Picker("", selection: $providerRaw) {
                Text("Gemini").tag(LLMProvider.gemini.rawValue)
                Text("OpenAI").tag(LLMProvider.openAI.rawValue)
                Text("Claude").tag(LLMProvider.claude.rawValue)
                Text("OpenRouter").tag(LLMProvider.openRouter.rawValue)
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }

        if providerRaw == LLMProvider.openRouter.rawValue {
            LabeledContent("Model ID") {
                TextField("meta-llama/llama-3-8b-instruct", text: $modelId)
            }
        }
    }
}

// MARK: - Color HEX 헬퍼
private extension Color {
    var hexString: String {
        guard let cgColor = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(cgColor.redComponent * 255)
        let g = Int(cgColor.greenComponent * 255)
        let b = Int(cgColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
