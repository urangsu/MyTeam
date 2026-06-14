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
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button {
                    selection = tab.id
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .padding(.horizontal, 6)
                    .foregroundStyle(selection == tab.id ? Color.white : Color.primary)
                    .background(
                        Capsule()
                            .fill(selection == tab.id ? Color.accentColor : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .padding(2)
        .background(
            Capsule()
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var manager: AgentWindowManager

    // ── 사용자 설정
    @AppStorage("userTitle")              private var userTitle: String = "수석님"
    @AppStorage("userLocation")           private var userLocation: String = "전남 광양"
    @AppStorage("teamName")               private var teamName: String = "MyTeam"
    @AppStorage(TeamNameplateAppearanceSettings.enabledKey) private var teamNameplateEnabled: Bool = TeamNameplateAppearanceSettings.defaultEnabled
    @AppStorage(TeamNameplateAppearanceSettings.paletteKey) private var teamNameplatePaletteRaw: String = TeamNameplateAppearanceSettings.defaultPalette.rawValue
    @AppStorage(TeamNameplateAppearanceSettings.borderModeKey) private var teamNameplateBorderModeRaw: String = TeamNameplateAppearanceSettings.defaultBorderMode.rawValue
    @AppStorage("agentWindowOpacity")     private var agentWindowOpacity: Double = 0.0

    @State private var currentTab: Int = 0
    @State private var focusedConnectionProvider: ExternalProvider? = nil
    @State private var focusedAssistantConnectorProvider: AssistantConnector.Provider? = nil
    @State private var skillSearchText: String = ""
    @State private var skillRefreshToken: UUID = UUID()
    @StateObject private var gps = LocationHelper()
    @StateObject private var credentialHealthService = CredentialHealthService.shared

    private let settingsTabs: [SettingsTabItem] = [
        .init(id: 0, title: "업무", icon: "bolt.fill"),
        .init(id: 1, title: "사용자", icon: "person.fill"),
        .init(id: 2, title: "연결", icon: "link"),
        .init(id: 3, title: "스킬", icon: "square.stack.3d.up"),
        .init(id: 4, title: "캐릭터", icon: "person.2.fill"),
        .init(id: 5, title: "음성", icon: "waveform")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SettingsTabBar(tabs: settingsTabs, selection: $currentTab)

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
                case 0: homeDashboardTab
                case 1: userSettingsTab
                case 2: connectionCenterTab
                case 3: skillsTab
                case 4: charactersTab
                case 5: TTSLabView()
                default: homeDashboardTab
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .preferredColorScheme(manager.isDarkMode ? .dark : .light)
        .frame(minWidth: 560, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            TeamNameplateAppearanceSettings.migrateLegacyValuesIfNeeded()
        }
        .onChange(of: gps.locationText) { _, newVal in
            if !newVal.isEmpty { userLocation = newVal }
        }
    }

    // MARK: - Tab 1: 기능 홈
    private var homeDashboardTab: some View {
        HomeDashboardView(onOpenConnection: { provider in
            focusedConnectionProvider = provider
            currentTab = 2
        }, onOpenAssistantConnection: { provider in
            focusedAssistantConnectorProvider = provider
            currentTab = 2
        }, onOpenWorkspace: { descriptor in
            if descriptor.category == .system {
                currentTab = 2
            } else {
                currentTab = descriptor.category == .voice ? 5 : 3
            }
        })
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

                // 팀 이름 명패 — compact card
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("팀 이름 명패", isOn: $teamNameplateEnabled)

                    if teamNameplateEnabled {
                        // 배경 팔레트
                        HStack(spacing: 6) {
                            ForEach(TeamNameplatePalette.allCases, id: \.rawValue) { palette in
                                let isSelected = teamNameplatePaletteRaw == palette.rawValue
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
                                    .onTapGesture { teamNameplatePaletteRaw = palette.rawValue }
                                    .help(palette.displayName)
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
                    set: { manager.isSilentMode = !$0 }
                )) {
                    Label("음성 출력", systemImage: "waveform")
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
                        let requiredProvider = skillRequiredProvider(skill)
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
                // 스토어 스켈레톤 (기존 캐릭터 역할/말투 수정 없음)
                CharacterStoreSkeletonView()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 기존 갤러리
                CharacterGalleryView()
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
