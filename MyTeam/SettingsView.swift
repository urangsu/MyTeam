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
                let locationName = try await Self.reverseGeocodedName(for: loc)
                await MainActor.run {
                    self.locationText = locationName.isEmpty ? "주소 변환 실패" : locationName
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.locationText = "주소 변환 실패"
                    self.isLoading = false
                }
            }
        }
    }

    nonisolated private static func reverseGeocodedName(for location: CLLocation) async throws -> String {
        if #available(macOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return "" }
            let items = try await request.mapItems
            guard let item = items.first else { return "" }
            if let address = item.addressRepresentations?.cityWithContext(.short)
                ?? item.addressRepresentations?.cityName {
                return address
            }
            return item.address?.shortAddress ?? item.address?.fullAddress ?? ""
        } else {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return Self.compactLocationName(
                    area: placemark.administrativeArea,
                    city: placemark.locality
                )
            }
            return ""
        }
    }

    nonisolated private static func compactLocationName(area: String?, city: String?) -> String {
        "\(area ?? "") \(city ?? "")".trimmingCharacters(in: .whitespaces)
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
    @AppStorage("useAnimalCrossingTTS")   private var useAnimalCrossingTTS: Bool = false

    // ── API 설정
    @AppStorage("defaultLLMProvider") private var defaultProviderRaw: String = LLMProvider.gemini.rawValue
    @AppStorage("openAIModelId")      private var openAIModelId: String = ""
    @State private var geminiKey: String = ""
    @State private var openAIKey: String = ""
    @State private var claudeKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var openRouterModelId: String = ""
    @State private var selectedProvider: LLMProvider = .gemini
    @State private var validationStatus: ValidationStatus = .idle
    @State private var showAdvancedModelSettings: Bool = false

    @State private var currentTab: Int = 0
    @State private var skillSearchText: String = ""
    @State private var skillRefreshToken: UUID = UUID()
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
                    Text("스킬").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button(action: { manager.hideSettingsWindow() }) {
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
                case 2: deskRoutingTab
                case 3: skillsTab
                default: deskRoutingTab
                }
            }
        }
        .preferredColorScheme(manager.isDarkMode ? .dark : .light)
        .frame(width: 420, height: 420)
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

            Section("음성") {
                Toggle(isOn: Binding(
                    get: { !manager.isSilentMode },
                    set: { manager.isSilentMode = !$0 }
                )) {
                    Label("음성 출력", systemImage: "waveform")
                }
                Toggle(isOn: $useAnimalCrossingTTS) {
                    Label("동물의숲 효과", systemImage: "sparkles")
                }
                .disabled(manager.isSilentMode)
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
                case .claude:
                    LabeledContent("Claude Key") {
                        SecureField("", text: $claudeKey)
                    }
                case .openRouter:
                    LabeledContent("OpenRouter Key") {
                        SecureField("", text: $openRouterKey)
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
                    if !currentKey(for: selectedProvider).isEmpty {
                        Button(role: .destructive) {
                            deleteCurrentKey()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.7))
                        .help("API 키 삭제")
                    }
                    Button("검증") { validateCurrentKey() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(currentKey(for: selectedProvider).isEmpty)
                }
            }

            Section {
                DisclosureGroup(isExpanded: $showAdvancedModelSettings) {
                    switch selectedProvider {
                    case .openAI:
                        LabeledContent("모델") {
                            TextField("자동", text: $openAIModelId)
                        }
                    case .openRouter:
                        LabeledContent("모델") {
                            TextField("자동", text: $openRouterModelId)
                        }
                    default:
                        EmptyView()
                    }

                    // 발견된 모델 목록
                    let discoveredModels = LLMConfigCatalog.shared.configs[selectedProvider]?.discoveredModels ?? []
                    if !discoveredModels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("발견된 모델")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(discoveredModels.prefix(8), id: \.self) { model in
                                Button {
                                    switch selectedProvider {
                                    case .openAI:     openAIModelId = model
                                    case .openRouter: openRouterModelId = model
                                    default: break
                                    }
                                } label: {
                                    HStack {
                                        Text(model)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if (selectedProvider == .openAI && openAIModelId == model) ||
                                           (selectedProvider == .openRouter && openRouterModelId == model) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Text(selectedProvider == .openRouter ? "모델 ID를 직접 입력하세요" : "자동 선택 (검증 후 갱신)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task {
                                    await LLMConfigCatalog.shared.refreshIfNeeded(selectedProvider)
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } label: {
                    Label("고급 모델 설정", systemImage: "slider.horizontal.3")
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

    // MARK: - Tab 4: 스킬 설정
    private var skillsTab: some View {
        let allSkills = SkillRegistry.shared.builtInSkills().sorted { $0.id < $1.id }
        let filtered = skillSearchText.isEmpty
            ? allSkills
            : allSkills.filter { skill in
                skill.name.lowercased().contains(skillSearchText.lowercased()) ||
                skill.id.lowercased().contains(skillSearchText.lowercased()) ||
                skill.description.lowercased().contains(skillSearchText.lowercased()) ||
                skill.triggers.contains { $0.lowercased().contains(skillSearchText.lowercased()) }
            }
        let enabledCount = SkillRegistry.shared.allEnabledSkills().count

        return VStack(spacing: 0) {
            // ── 헤더: 내 팀의 능력
            VStack(alignment: .leading, spacing: 4) {
                Text("내 팀의 능력 관리")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text("내 팀이 사용할 수 있는 한국형 업무 능력입니다. 필요한 스킬만 켜두면 팀원이 대화 중 자동으로 사용합니다.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // ── 검색바
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField("스킬 이름, ID, 설명 검색...", text: $skillSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !skillSearchText.isEmpty {
                        Button(action: { skillSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(enabledCount)/\(allSkills.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                    Text("활성화됨")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // ── 스킬 리스트
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filtered, id: \.id) { skill in
                        SkillRowView(
                            skill: skill,
                            isEnabled: SkillRegistry.shared.isSkillEnabled(id: skill.id),
                            onToggle: { newValue in
                                SkillRegistry.shared.setSkillEnabled(id: skill.id, enabled: newValue)
                                skillRefreshToken = UUID()
                            }
                        )
                    }

                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.3))
                            Text(skillSearchText.isEmpty ? "로드된 스킬이 없습니다." : "검색 결과가 없습니다.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Divider()

            // ── 푸터
            HStack {
                Label("안전한 로컬 처리 우선", systemImage: "shield.checkered")
                    .font(.system(size: 10))
                    .foregroundColor(.green.opacity(0.8))
                Spacer()
                Text("V\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .id(skillRefreshToken)
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

    private func deleteCurrentKey() {
        let keychainKey: String
        switch selectedProvider {
        case .gemini:     keychainKey = "geminiAPIKey"; geminiKey = ""
        case .openAI:     keychainKey = "openAIAPIKey"; openAIKey = ""
        case .claude:     keychainKey = "claudeAPIKey"; claudeKey = ""
        case .openRouter: keychainKey = "openRouterAPIKey"; openRouterKey = ""
        }
        _ = KeychainManager.delete(key: keychainKey)
        validationStatus = .idle
    }

    private func loadSettings() {
        if let k = KeychainManager.load(key: "geminiAPIKey")     { geminiKey = k }
        if let k = KeychainManager.load(key: "openAIAPIKey")     { openAIKey = k }
        if let k = KeychainManager.load(key: "claudeAPIKey")     { claudeKey = k }
        if let k = KeychainManager.load(key: "openRouterAPIKey") { openRouterKey = k }
        openRouterModelId = UserDefaults.standard.string(forKey: "openRouterModelId")
            ?? ""
        if let raw = LLMProvider(rawValue: defaultProviderRaw) { selectedProvider = raw }
    }

    private func saveSettings() {
        openAIModelId = openAIModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        openRouterModelId = openRouterModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainManager.save(key: "geminiAPIKey",     value: geminiKey)
        KeychainManager.save(key: "openAIAPIKey",     value: openAIKey)
        KeychainManager.save(key: "claudeAPIKey",     value: claudeKey)
        KeychainManager.save(key: "openRouterAPIKey", value: openRouterKey)
        if openAIModelId.isEmpty {
            UserDefaults.standard.removeObject(forKey: "openAIModelId")
        }
        if openRouterModelId.isEmpty {
            UserDefaults.standard.removeObject(forKey: "openRouterModelId")
        } else {
            UserDefaults.standard.set(openRouterModelId, forKey: "openRouterModelId")
        }
        defaultProviderRaw = selectedProvider.rawValue
    }
}

private struct SkillRowView: View {
    let skill: SkillManifest
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        let isHighRisk = SkillRegistry.isHighRiskSkill(skill)
        HStack(alignment: .top, spacing: 10) {
            Text(iconForCategory(skill.category))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.body)
                Text(skill.description.isEmpty ? skill.id : skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    label(riskLabel(for: skill.riskLevel), color: isHighRisk ? .orange : riskColor(for: skill.riskLevel))
                    label(processingLabel(for: skill), color: processingColor(for: skill))
                    if isHighRisk && !isEnabled {
                        label("잠김", color: .orange)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .disabled(isHighRisk && !isEnabled)
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private func iconForCategory(_ category: SkillCategory) -> String {
        switch category {
        case .koreanLife: return "☁"
        case .koreanWriting: return "가"
        case .koreanBusiness: return "💼"
        case .koreanLegal: return "⚖"
        case .koreanFinance: return "▦"
        case .document: return "📄"
        case .diagnostics: return "◇"
        default: return "•"
        }
    }

    private func riskLabel(for risk: SkillRiskLevel) -> String {
        switch risk {
        case .safeReadOnly: return "안전"
        case .publicData: return "공개 데이터"
        case .personalData: return "개인정보"
        case .accountLogin: return "로그인"
        case .externalWrite: return "외부 쓰기"
        case .reservation: return "예약"
        case .payment: return "결제"
        case .regulated: return "민감 작업"
        }
    }

    private func riskColor(for risk: SkillRiskLevel) -> Color {
        switch risk {
        case .safeReadOnly: return .green
        case .publicData: return .blue
        default: return .orange
        }
    }

    private func processingLabel(for skill: SkillManifest) -> String {
        if skill.id == "korean.character-count" || skill.requiredPermissions.isEmpty {
            return "로컬"
        }
        if skill.requiredPermissions.contains(.usePublicAPI) || skill.requiredPermissions.contains(.usePublicWeb) {
            return "공개 데이터"
        }
        return "표준 처리"
    }

    private func processingColor(for skill: SkillManifest) -> Color {
        skill.requiredPermissions.isEmpty ? .green : .secondary
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
        _modelId     = AppStorage(wrappedValue: "",
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
            DisclosureGroup {
                LabeledContent("모델") {
                    TextField("자동", text: $modelId)
                }
            } label: {
                Text("고급 모델 설정")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
