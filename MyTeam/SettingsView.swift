import SwiftUI
import AppKit
import Combine
@preconcurrency import CoreLocation
@preconcurrency import MapKit

enum SettingsSurfaceCopy {
    static let skillSearchPlaceholder = "스킬 이름이나 설명 검색"

    nonisolated static func builtInSkillSectionTitle(enabled: Int, total: Int) -> String {
        "기본 스킬 (\(enabled)/\(total) 활성화)"
    }
}

enum SettingsSurfacePolicy {
    static func showsVoiceLab(in profile: AppReleaseProfile) -> Bool {
        TTSProductPolicy.labEnabled(for: profile)
    }
}

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
    // Round 278 3-B: 거부 상태 캐싱 — 시스템 창 반복 표시 방지 + UI에서 설정 링크 노출
    @Published var isPermissionDenied: Bool = false

    private let mgr = CLLocationManager()

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // 초기 권한 상태 동기화
        isPermissionDenied = (mgr.authorizationStatus == .denied || mgr.authorizationStatus == .restricted)
    }

    func request() {
        // Round 278 3-B: 거부/제한 상태면 권한 요청 호출 자체를 스킵하고 시스템 설정 열기.
        switch mgr.authorizationStatus {
        case .notDetermined:
            isLoading = true
            mgr.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            isLoading = true
            isPermissionDenied = false
            mgr.requestLocation()
        case .denied, .restricted:
            isPermissionDenied = true
            locationText = "위치 권한이 꺼져 있어요. 시스템 설정에서 켜주세요."
            isLoading = false
            // 시스템 설정 > 개인정보 보호 > 위치 서비스 직접 열기
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                NSWorkspace.shared.open(url)
            }
        @unknown default:
            locationText = "위치 권한 상태를 확인할 수 없어요."
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
            // Round 278 3-B: isPermissionDenied도 함께 동기화
            self.isPermissionDenied = (status == .denied || status == .restricted)
            if status == .authorizedAlways || status == .authorized {
                self.mgr.requestLocation()
            } else if status == .denied || status == .restricted {
                self.locationText = "위치 권한이 꺼져 있어요."
                self.isLoading = false
            }
        }
    }
}

private struct SettingsTabItem: Identifiable {
    let id: Int
    let title: String
    let icon: String
}

private struct SettingsTabBar: View {
    let tabs: [SettingsTabItem]
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("설정")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ForEach(tabs) { tab in
                Button {
                    selection = tab.id
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 18)
                        Text(tab.title)
                            .font(.system(size: 13, weight: selection == tab.id ? .semibold : .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .padding(.horizontal, 10)
                    .foregroundStyle(selection == tab.id ? Color.accentColor : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection == tab.id ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager

    // ── 사용자 설정
    @AppStorage("userTitle")              private var userTitle: String = "수석님"
    @AppStorage("userLocation")           private var userLocation: String = ""
    @AppStorage("teamName")               private var teamName: String = "MyTeam"
    @AppStorage(TeamNameplateAppearanceSettings.enabledKey) private var teamNameplateEnabled: Bool = TeamNameplateAppearanceSettings.defaultEnabled
    @AppStorage(TeamNameplateAppearanceSettings.paletteKey) private var teamNameplatePaletteRaw: String = TeamNameplateAppearanceSettings.defaultPalette.rawValue
    @AppStorage(TeamNameplateAppearanceSettings.borderModeKey) private var teamNameplateBorderModeRaw: String = TeamNameplateAppearanceSettings.defaultBorderMode.rawValue
    @AppStorage("agentWindowOpacity")     private var agentWindowOpacity: Double = 0.0
    @AppStorage(TerminationFarewellPreference.key) private var terminationFarewellEnabled: Bool = false

    @State private var currentTab: Int = 0
    @State private var focusedConnectionProvider: ExternalProvider? = nil
    @State private var focusedAssistantConnectorProvider: AssistantConnector.Provider? = nil
    @State private var skillSearchText: String = ""
    @State private var skillRefreshToken: UUID = UUID()
    @StateObject private var gps = LocationHelper()
    @StateObject private var credentialHealthService = CredentialHealthService.shared

    private var settingsTabs: [SettingsTabItem] {
        var tabs = [
            SettingsTabItem(id: 0, title: "업무", icon: "bolt.fill"),
            SettingsTabItem(id: 1, title: "사용자", icon: "person.fill"),
            SettingsTabItem(id: 2, title: "연결", icon: "link"),
            SettingsTabItem(id: 3, title: "스킬", icon: "square.stack.3d.up"),
            SettingsTabItem(id: 4, title: "캐릭터", icon: "person.2.fill")
        ]
        if SettingsSurfacePolicy.showsVoiceLab(in: AppReleaseProfile.current) {
            tabs.append(.init(id: 5, title: "음성", icon: "waveform"))
        }
        return tabs
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MyTeam")
                        .font(.system(size: 15, weight: .semibold))
                    Text("환경설정")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)

                SettingsTabBar(tabs: settingsTabs, selection: $currentTab)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 176)
            .background(.ultraThinMaterial)

            Divider()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedSettingsTab.title)
                        .font(.system(size: 24, weight: .semibold))
                    Text(selectedSettingsTabSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                Group {
                    switch currentTab {
                    case 0: homeDashboardTab
                    case 1: userSettingsTab
                    case 2: connectionCenterTab
                    case 3: skillsTab
                    case 4: charactersTab
                    case 5:
                        if SettingsSurfacePolicy.showsVoiceLab(in: AppReleaseProfile.current) {
                            TTSLabView()
                        } else {
                            homeDashboardTab
                        }
                    default: homeDashboardTab
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .preferredColorScheme(manager.isDarkMode ? .dark : .light)
        .frame(minWidth: 720, minHeight: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            TeamNameplateAppearanceSettings.migrateLegacyValuesIfNeeded()
        }
        .onChange(of: gps.locationText) { _, newVal in
            if !newVal.isEmpty { userLocation = newVal }
        }
        .onChange(of: terminationFarewellEnabled) { _, enabled in
            AppTerminationSpeechService.shared.preferenceDidChange(enabled: enabled, manager: manager)
        }
    }

    private var selectedSettingsTab: SettingsTabItem {
        settingsTabs.first(where: { $0.id == currentTab }) ?? settingsTabs[0]
    }

    private var selectedSettingsTabSubtitle: String {
        switch currentTab {
        case 0: return "MyTeam의 업무 기능과 현재 준비 상태를 확인합니다."
        case 1: return "나와 MyTeam이 함께 일하고 대화하는 방식을 설정합니다."
        case 2: return "AI와 외부 서비스 연결을 안전하게 관리합니다."
        case 3: return "필요한 업무 능력만 선택해 사용합니다."
        case 4: return "함께 일할 팀원과 캐릭터 구성을 관리합니다."
        case 5: return "캐릭터 음성을 미리 듣고 조절합니다."
        default: return "MyTeam 설정을 관리합니다."
        }
    }

    // MARK: - Tab 1: 기능 홈
    private var homeDashboardTab: some View {
        WorkCapabilitySettingsView(
            onOpenConnection: { provider in
                focusedConnectionProvider = provider
                currentTab = 2
            },
            onOpenAssistantConnection: { provider in
                focusedAssistantConnectorProvider = provider
                currentTab = 2
            }
        )
    }

    // MARK: - Tab 2: 사용자 설정
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
                        .help("현재 위치 가져오기")
                        .accessibilityLabel("현재 위치 가져오기")
                        TextField("예: 광양", text: $userLocation)
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

                // 팀 이름 명패 — compact card
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("팀 이름 명패", isOn: $teamNameplateEnabled)

                    if teamNameplateEnabled {
                        // 배경 팔레트
                        HStack(spacing: 6) {
                            ForEach(TeamNameplatePalette.allCases, id: \.rawValue) { palette in
                                let isSelected = teamNameplatePaletteRaw == palette.rawValue
                                Button {
                                    teamNameplatePaletteRaw = palette.rawValue
                                } label: {
                                    Circle()
                                        .fill(palette == .clear ? Color.gray.opacity(0.15) : palette.color.opacity(0.85))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle().stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                        .overlay(
                                            palette == .clear
                                                ? Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                                                : nil
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(palette.displayName)
                                .accessibilityLabel("\(palette.displayName) 명패 색상")
                                .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
                            }
                        }
                        .padding(.top, 2)

                        // 테두리 on/off
                        Picker("테두리", selection: $teamNameplateBorderModeRaw) {
                            ForEach(TeamNameplateBorderMode.allCases, id: \.rawValue) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)
                    }
                }
            }

            Section("팀원창") {
                LabeledContent("투명도 \(Int(agentWindowOpacity * 100))%") {
                    Slider(value: $agentWindowOpacity, in: 0...1.0, step: 0.05)
                        .frame(minWidth: 140)
                }
            }

            // MARK: - 간편 모드
            Section {
                Toggle(isOn: $manager.isBeginnerMode) {
                    Label("간편 모드", systemImage: "sparkles")
                }
                if manager.isBeginnerMode {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("회의록, 체크리스트, 파일 읽기, 오늘 할 일을 버튼으로 시작합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("API 연결 없이도 로컬 기능부터 사용할 수 있어요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            } header: {
                Text("시작 방식")
            } footer: {
                Text("AI가 익숙하지 않아도 업무 카드로 바로 시작할 수 있어요.")
                    .font(.caption2)
            }

            Section("음성") {
                Toggle(isOn: Binding(
                    get: { !manager.isSilentMode },
                    set: { enabled in
                        manager.isSilentMode = !enabled
                        AppTerminationSpeechService.shared.preferenceDidChange(
                            enabled: terminationFarewellEnabled,
                            manager: manager
                        )
                    }
                )) {
                    Label("음성 출력", systemImage: "waveform")
                }
                .disabled(!TTSProductPolicy.userFacingTTSEnabled)

                Toggle(isOn: $terminationFarewellEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("종료 인사", systemImage: "moon.stars")
                        Text("MyTeam을 종료할 때 팀장이 짧은 인사를 들려줍니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!TTSProductPolicy.userFacingTTSEnabled)

                if !TTSProductPolicy.userFacingTTSEnabled {
                    Text("Supertonic3가 MyTeam의 단일 TTS 엔진입니다. 모델·고지·런타임 조건이 충족되면 말하기 버튼에서 재생됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Tab 2: 연결 센터
    private var connectionCenterTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ConnectionCenterView(focusedProvider: focusedConnectionProvider)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(.blue)
                        Text("비서 연결")
                            .font(.system(size: 13, weight: .semibold))
                        if let focusedAssistantConnectorProvider {
                            Text(focusedAssistantConnectorProvider.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.10)))
                        }
                    }

                    AssistantConnectorCenterView()
                }
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Tab 3: 스킬 설정
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
                TextField(SettingsSurfaceCopy.skillSearchPlaceholder, text: $skillSearchText)
                    .textFieldStyle(.roundedBorder)

                Text("\(enabledCount)/\(builtInSkills.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            Form {
                Section(SettingsSurfaceCopy.builtInSkillSectionTitle(enabled: enabledCount, total: builtInSkills.count)) {
                    ForEach(filteredSkills, id: \.id) { skill in
                        let isEnabled = SkillRegistry.shared.isSkillEnabled(id: skill.id)
                        let isHighRisk = SkillRegistry.isHighRiskSkill(skill)
                        let requiredProvider = skillRequiredProvider(skill)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skill.name)
                                    .font(.body)
                                Text(skill.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
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
                            if let requiredProvider {
                                skillConnectionButton(for: requiredProvider)
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

                // 시스템 진단 — 개발자/Debug 모드에서만 표시
                if AppReleaseProfile.current.policy.showsDeveloperDiagnostics {
                    Section("시스템 진단") {
                        RuntimeDiagnosticsPlaceholder(manager: manager)
                        ChainRuntimeSmokeDiagnosticsView()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func skillRequiredProvider(_ skill: SkillManifest) -> ExternalProvider? {
        switch skill.id {
        case "korean.weather", "korean.fine-dust":
            return .kmaWeather
        case "korean.naver-news", "korean.naver-blog-research":
            return .naverNews
        case "korean.dart":
            return .dartDisclosure
        case "korean.law-search":
            return .koreanLaw
        default:
            return nil
        }
    }

    @ViewBuilder
    private func skillConnectionButton(for provider: ExternalProvider) -> some View {
        let health = credentialHealthService.health(for: provider)
        Button {
            focusedConnectionProvider = provider
            currentTab = 2
        } label: {
            Image(systemName: skillConnectionIcon(for: health.state))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(skillConnectionColor(for: health.state))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(skillConnectionColor(for: health.state).opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .help("\(provider.displayName): \(health.state.displayLabel)")
    }

    private func skillConnectionIcon(for state: CredentialHealthState) -> String {
        switch state {
        case .connected:
            return "key.fill"
        case .untested, .testUnavailable:
            return "key"
        case .testFailed:
            return "exclamationmark.triangle.fill"
        case .notConnected:
            return "key.slash"
        }
    }

    private func skillConnectionColor(for state: CredentialHealthState) -> Color {
        switch state {
        case .connected:
            return .green
        case .untested, .testUnavailable:
            return .blue
        case .testFailed:
            return .orange
        case .notConnected:
            return .secondary
        }
    }

    // MARK: - Tab 4: 캐릭터
    private var charactersTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                CharacterGalleryView()
            }
            .padding(.top, 12)
        }
    }

}

private struct WorkCapabilitySettingsView: View {
    let onOpenConnection: (ExternalProvider?) -> Void
    let onOpenAssistantConnection: (AssistantConnector.Provider?) -> Void

    @State private var states: [String: ToolExecutionState] = [:]
    @State private var isRefreshing = false

    private var tools: [MyTeamToolDescriptor] {
        MyTeamToolRegistry.userFacingTools
            .filter { descriptor in
                guard descriptor.category != .system, descriptor.category != .voice else { return false }
                switch ProductSurfacePolicy.tier(for: descriptor) {
                case .primary, .secondary, .naturalOnly, .connectionOnly:
                    return descriptor.isImplemented
                case .developerOnly, .hidden:
                    return false
                }
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("기능 상태")
                            .font(.system(size: 14, weight: .semibold))
                        Text("기능을 끄면 대화창과 협업창에서도 실행되지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: refresh) {
                        if isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("다시 확인", systemImage: "arrow.clockwise")
                        }
                    }
                    .controlSize(.small)
                    .disabled(isRefreshing)
                }

                VStack(spacing: 0) {
                    ForEach(Array(tools.enumerated()), id: \.element.id) { index, descriptor in
                        capabilityRow(descriptor)
                        if index < tools.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
            }
            .padding(20)
        }
    }

    private func capabilityRow(_ descriptor: MyTeamToolDescriptor) -> some View {
        let isEnabled = MyTeamToolPreference.isEnabled(id: descriptor.id)
        let state = states[descriptor.id]
        return HStack(spacing: 12) {
            Image(systemName: icon(for: descriptor.category))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(isEnabled ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(isEnabled ? state.map(statusText(for:)) ?? "확인 전" : "꺼짐")
                    .font(.caption)
                    .foregroundStyle(statusColor(for: state, isEnabled: isEnabled))
            }

            Spacer(minLength: 12)

            if let state {
                connectionButton(for: state)
            }

            Toggle("", isOn: Binding(
                get: { MyTeamToolPreference.isEnabled(id: descriptor.id) },
                set: { enabled in
                    MyTeamToolPreference.setEnabled(enabled, id: descriptor.id)
                    if enabled {
                        Task { await refreshState(for: descriptor) }
                    } else {
                        states[descriptor.id] = .unavailable("설정에서 꺼져 있습니다.")
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel("\(descriptor.displayName) 사용")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func connectionButton(for state: ToolExecutionState) -> some View {
        switch state {
        case .needsConnection(let provider), .needsValidation(let provider):
            Button("연결 확인") { onOpenConnection(provider) }
                .controlSize(.small)
        case .needsAssistantConnection(let provider):
            Button("연결 확인") { onOpenAssistantConnection(provider) }
                .controlSize(.small)
        default:
            EmptyView()
        }
    }

    private func statusText(for state: ToolExecutionState) -> String {
        switch state {
        case .idle: return "사용 가능"
        case .checkingReadiness: return "확인 중"
        case .needsConnection, .needsAssistantConnection: return "연결 필요"
        case .needsValidation: return "연결 점검 필요"
        case .needsApproval: return "실행할 때 승인 필요"
        case .unavailable(let reason): return reason
        case .failed(let failure): return failure.message
        default: return state.displayLabel
        }
    }

    private func statusColor(for state: ToolExecutionState?, isEnabled: Bool) -> Color {
        guard isEnabled else { return .secondary }
        guard let state else { return .secondary }
        switch state {
        case .idle: return .secondary
        case .needsConnection, .needsAssistantConnection, .needsValidation, .needsApproval: return .orange
        case .failed, .unavailable: return .red
        default: return .secondary
        }
    }

    private func icon(for category: MyTeamToolCategory) -> String {
        switch category {
        case .briefing: return "sun.max"
        case .document: return "doc.text"
        case .spreadsheet: return "tablecells"
        case .externalInfo: return "globe.asia.australia"
        case .calendar: return "calendar"
        case .mail: return "envelope"
        case .voice: return "waveform"
        case .system: return "gearshape"
        }
    }

    private func refresh() {
        Task { await refreshStates() }
    }

    private func refreshStates() async {
        await MainActor.run { isRefreshing = true }
        for descriptor in tools {
            await refreshState(for: descriptor)
        }
        await MainActor.run { isRefreshing = false }
    }

    private func refreshState(for descriptor: MyTeamToolDescriptor) async {
        let state = await ToolExecutionRouter.shared.readiness(for: descriptor)
        await MainActor.run { states[descriptor.id] = state }
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
                    if DiagnosticsVisibilityPolicy.allowsVerboseDiagnostics {
                        DiagnosticRow(label: "워크플로우", value: diag.isWorkflowRunning ? "실행 중" : "대기")
                        DiagnosticRow(label: "이벤트", value: "\(diag.recentEventCount)건")
                        if let summary = diag.latestEventSummary, !summary.isEmpty {
                            DiagnosticRow(label: "최근", value: summary)
                        }
                        let geminiStatus = (diag.geminiCooldownRemainingSeconds ?? 0) > 0
                            ? "쿨다운 \(Int(diag.geminiCooldownRemainingSeconds ?? 0))s"
                            : "준비됨"
                        DiagnosticRow(label: "Gemini", value: geminiStatus)
                    } else {
                        // Release: 내부 플래그 대신 간결한 상태 1줄만 표시
                        DiagnosticRow(label: "상태", value: "정상")
                    }
                }
            } else {
                Text("새로고침을 눌러 진단 정보를 불러옵니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
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

private struct ChainRuntimeSmokeDiagnosticsView: View {
    @State private var isRunning = false
    @State private var results: [ChainRuntimeSmokeCaseResult] = []

    private var failedResults: [ChainRuntimeSmokeCaseResult] {
        results.filter { !$0.issues.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Chain Runtime Smoke", systemImage: "checklist.checked")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    runSmoke()
                } label: {
                    if isRunning {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Text("실행")
                    }
                }
                .controlSize(.small)
                .disabled(isRunning)
            }

            if results.isEmpty {
                Text("주가·메일·문서·액션 체인 안전 경로를 온디맨드로 점검합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                DiagnosticRow(
                    label: "Smoke",
                    value: failedResults.isEmpty ? "\(results.count)건 통과" : "\(failedResults.count)/\(results.count)건 확인 필요"
                )

                ForEach(results, id: \.name) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: result.issues.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(result.issues.isEmpty ? .green : .orange)
                            Text(result.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text(result.verificationStatus ?? "no-route")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if !result.issues.isEmpty {
                            ForEach(result.issues, id: \.self) { issue in
                                Text(issue)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func runSmoke() {
        isRunning = true
        Task {
            let smokeResults = await ChainRuntimeSmokeSuite.run()
            await MainActor.run {
                results = smokeResults
                isRunning = false
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
