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
    @ObservedObject private var appEntitlementManager = AppEntitlementManager.shared

    // ── 사용자 설정
    @AppStorage("userTitle")              private var userTitle: String = "수석님"
    @AppStorage("userLocation")           private var userLocation: String = "전남 광양"
    @AppStorage("teamName")               private var teamName: String = "MyTeam"
    @AppStorage(TeamNameplateAppearanceSettings.enabledKey) private var teamNameplateEnabled: Bool = TeamNameplateAppearanceSettings.defaultEnabled
    @AppStorage(TeamNameplateAppearanceSettings.colorHexKey) private var teamNameplateColorHex: String = TeamNameplateAppearanceSettings.defaultColorHex
    @AppStorage(TeamNameplateAppearanceSettings.borderColorHexKey) private var teamNameplateBorderColorHex: String = TeamNameplateAppearanceSettings.defaultBorderColorHex
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
    @State private var dailyBriefingPreview: DailyBriefing = DailyBriefingService.makeUnavailableBriefing(
        now: Date(),
        manager: AgentWindowManager.shared
    )
    @State private var dailyBriefingRefreshToken = UUID()

    @State private var currentTab: Int = 0
    @State private var skillSearchText: String = ""
    @State private var skillRefreshToken: UUID = UUID()
    @StateObject private var gps = LocationHelper()

    var body: some View {
        VStack(spacing: 0) {
            // ── 탭 세그먼트 + X 버튼 (같은 라인)
            HStack(spacing: 8) {
                Picker("", selection: $currentTab) {
                    Text("사용자 설정").tag(0)
                    Text("API 설정").tag(1)
                    Text("데스크 라우팅").tag(2)
                    Text("스킬").tag(3)
                    Text("캐릭터").tag(4)
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
                case 4: charactersTab
                default: deskRoutingTab
                }
            }
        }
        .preferredColorScheme(manager.isDarkMode ? .dark : .light)
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            TeamNameplateAppearanceSettings.migrateLegacyValuesIfNeeded()
            loadSettings()
        }
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
                    }
                } label: {
                    Label("팀 이름", systemImage: "flag.fill")
                }

                Toggle("팀 이름 명패 표시", isOn: $teamNameplateEnabled)

                DisclosureGroup("팀 이름 명패") {
                    VStack(alignment: .leading, spacing: 10) {
                        nameplatePaletteRow(
                            title: "배경",
                            selection: $teamNameplateColorHex,
                            presets: TeamNameplateAppearanceSettings.colorPresets
                        )

                        nameplatePaletteRow(
                            title: "테두리",
                            selection: $teamNameplateBorderColorHex,
                            presets: TeamNameplateAppearanceSettings.borderColorPresets
                        )
                    }
                    .padding(.top, 4)
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
            Section("BYOK / 사용 정책") {
                BYOKProviderCenterView()
                UsagePolicyCardView()
            }

            Section("비서 연결") {
                AssistantConnectorCenterView(onGoogleCalendarConnectionChanged: {
                    dailyBriefingRefreshToken = UUID()
                })
            }

            Section("오늘 브리핑") {
                DailyBriefingCardView(
                    briefing: dailyBriefingPreview,
                    onActionTap: handleBriefingAction
                )
            }

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
        .task(id: dailyBriefingRefreshToken) {
            await refreshDailyBriefingPreview()
        }
    }

    @MainActor
    private func handleBriefingAction(_ suggestion: BriefingActionSuggestion) {
        guard let roomID = manager.currentRoomID else { return }

        if let systemActionID = suggestion.systemActionID {
            switch systemActionID {
            case "openSchedulePanel":
                manager.isSchedulePanelPresented = true
                return
            default:
                break
            }
        }

        guard let prompt = suggestion.prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
              !prompt.isEmpty else {
            return
        }

        manager.addChatLog(
            roomID: roomID,
            agentID: "user",
            agentName: "나",
            text: prompt,
            isUser: true
        )

        Task {
            await WorkflowOrchestrator.shared.dispatch(
                userMessage: prompt,
                roomID: roomID,
                manager: manager
            )
        }
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
        let _ = skillRefreshToken
        let builtInSkills = SkillRegistry.shared.builtInSkills().sorted { $0.id < $1.id }
        let filteredSkills = skillSearchText.isEmpty
            ? builtInSkills
            : builtInSkills.filter { skill in
                let query = skillSearchText.lowercased()
                return skill.name.lowercased().contains(query)
                    || skill.id.lowercased().contains(query)
                    || skill.description.lowercased().contains(query)
                    || skill.triggers.contains(where: { $0.lowercased().contains(query) })
            }
        let enabledCount = SkillRegistry.shared.allEnabledSkills().count
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("스킬 이름, ID, 설명 검색", text: $skillSearchText)
                    .textFieldStyle(.roundedBorder)

                Text("\(enabledCount)/\(builtInSkills.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            Form {
                Section("Built-in 스킬 (\(enabledCount)/\(builtInSkills.count) 활성화)") {
                    ForEach(filteredSkills, id: \.id) { skill in
                        let isEnabled = SkillRegistry.shared.isSkillEnabled(id: skill.id)
                        let isHighRisk = SkillRegistry.isHighRiskSkill(skill)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skill.name)
                                    .font(.body)
                                Text(skill.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isHighRisk && !isEnabled {
                                Text("민감 작업")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            Toggle("", isOn: Binding(
                                get: { isEnabled },
                                set: { newValue in
                                    SkillRegistry.shared.setSkillEnabled(id: skill.id, enabled: newValue)
                                    skillRefreshToken = UUID()
                                }
                            ))
                            .disabled(isHighRisk && !isEnabled)
                        }
                    }
                }

                Section("사용자 추가 스킬") {
                    Text("다음 단계에서 지원 예정입니다.")
                        .foregroundStyle(.secondary)
                }

                Section("시스템 진단") {
                    RuntimeDiagnosticsPlaceholder(manager: manager)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Tab 5: 캐릭터
    private var charactersTab: some View {
        VStack(spacing: 0) {
            planSummaryCard
            Divider()
            CharacterGalleryView()
        }
    }

    private var planSummaryCard: some View {
        let limits = appEntitlementManager.currentLimits
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("플랜")
                        .font(.system(size: 14, weight: .semibold))
                    Text("현재 플랜: \(appEntitlementManager.currentPlan.displayName)")
                        .font(.system(size: 12, weight: .medium))
                    Text("기본 제공량은 온보딩용 placeholder이며, 초과 사용은 개인 API 키 연결을 전제로 합니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("출시 예정") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
            }

            HStack(spacing: 8) {
                planBadge("일 \(limits.includedAIMessagesPerDay)회")
                planBadge("BYOK 지원")
                planBadge("결제 출시 예정")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func planBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
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
        dailyBriefingRefreshToken = UUID()
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

    @MainActor
    private func refreshDailyBriefingPreview() async {
        let provider = GoogleDailyBriefingCalendarProvider.shared
        let briefing = await DailyBriefingService.makePreviewBriefing(
            now: Date(),
            calendarProvider: provider,
            manager: AgentWindowManager.shared
        )
        dailyBriefingPreview = briefing
    }

    private func nameplatePaletteRow(
        title: String,
        selection: Binding<String>,
        presets: [TeamNameplateColorPreset]
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(presets) { preset in
                    Button {
                        selection.wrappedValue = preset.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(TeamNameplateAppearanceSettings.color(from: preset.hex))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selection.wrappedValue.uppercased() == preset.hex.uppercased()
                                            ? Color.primary.opacity(0.75)
                                            : Color.secondary.opacity(0.18),
                                            lineWidth: selection.wrappedValue.uppercased() == preset.hex.uppercased() ? 2 : 1
                                        )
                                )

                            if selection.wrappedValue.uppercased() == preset.hex.uppercased() {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(TeamNameplateAppearanceSettings.isTransparent(preset.hex) ? .primary : .white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!teamNameplateEnabled)
                    .help(preset.name)
                }
            }

            Spacer(minLength: 0)
        }
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

// MARK: - RuntimeDiagnosticsPlaceholder
struct RuntimeDiagnosticsPlaceholder: View {
    @ObservedObject var manager: AgentWindowManager
    @State private var diagnostics: RuntimeDiagnosticsSnapshot?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with refresh button
            HStack {
                Text("시스템 상태")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: refreshDiagnostics) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            // Diagnostics content or error
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let diag = diagnostics {
                VStack(alignment: .leading, spacing: 8) {
                    DiagnosticRow(label: "워크플로우", value: diag.isWorkflowRunning ? "실행 중" : "대기")
                    DiagnosticRow(label: "이벤트", value: "\(diag.recentEventCount)건")
                    if let summary = diag.latestEventSummary, !summary.isEmpty {
                        DiagnosticRow(label: "최근", value: summary)
                    }
                    let geminiStatus = (diag.geminiCooldownRemainingSeconds ?? 0) > 0
                        ? "쿨다운 \(Int(diag.geminiCooldownRemainingSeconds ?? 0))s"
                        : "준비됨"
                    DiagnosticRow(label: "Gemini", value: geminiStatus)
                }
            } else {
                Text("새로고침을 눌러 진단 정보를 불러옵니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            refreshDiagnostics()
        }
    }

    private func refreshDiagnostics() {
        isLoading = true
        errorMessage = nil
        Task {
            let snapshot = await RuntimeDiagnosticsService.shared.snapshot(manager: manager)
            await MainActor.run {
                self.diagnostics = snapshot
                self.isLoading = false
            }
        }
    }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Spacer()
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
