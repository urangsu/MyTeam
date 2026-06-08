import SwiftUI

struct HomeDashboardView: View {
    let onOpenConnection: (ExternalProvider?) -> Void
    let onOpenWorkspace: (MyTeamToolDescriptor) -> Void

    @State private var toolStates: [String: ToolExecutionState] = [:]
    @State private var toolQueries: [String: String] = [
        "dart.disclosures.search": "포스코",
        "news.search": "경제",
        "weather.current": "서울",
        "law.search": "근로기준법"
    ]
    @State private var selectedState: ToolExecutionState? = nil
    @State private var selectedDescriptor: MyTeamToolDescriptor? = nil

    private let quickToolIDs = [
        "document.meetingMinutes",
        "spreadsheet.postprocess",
        "weather.current",
        "dart.disclosures.search",
        "news.search",
        "law.search",
        "voice.bubbleSpeech.preview"
    ]

    private var quickTools: [MyTeamToolDescriptor] {
        quickToolIDs.compactMap(MyTeamToolRegistry.descriptor)
    }

    private var connectionTools: [MyTeamToolDescriptor] {
        MyTeamToolRegistry.userFacingTools.filter {
            if case .needsConnection = state(for: $0) { return true }
            if case .needsValidation = state(for: $0) { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let briefing = MyTeamToolRegistry.descriptor(id: "briefing.today") {
                    ToolActionCardView(
                        descriptor: briefing,
                        state: state(for: briefing),
                        query: nil,
                        onRun: nil,
                        onOpenWorkspace: onOpenWorkspace,
                        onOpenConnection: onOpenConnection
                    )
                }

                dashboardSection(title: "업무 바로가기") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                        ForEach(quickTools) { descriptor in
                            ToolActionCardView(
                                descriptor: descriptor,
                                state: state(for: descriptor),
                                query: queryBinding(for: descriptor),
                                onRun: run,
                                onOpenWorkspace: onOpenWorkspace,
                                onOpenConnection: onOpenConnection
                            )
                        }
                    }
                }

                dashboardSection(title: "연결이 필요한 업무") {
                    if connectionTools.isEmpty {
                        Text("지금 바로 연결이 필요한 기능은 없습니다.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(connectionTools.prefix(4)) { descriptor in
                                ToolActionCardView(
                                    descriptor: descriptor,
                                    state: state(for: descriptor),
                                    query: queryBinding(for: descriptor),
                                    onRun: run,
                                    onOpenWorkspace: onOpenWorkspace,
                                    onOpenConnection: onOpenConnection
                                )
                            }
                        }
                    }
                }

                if let selectedState {
                    ToolResultCardView(
                        state: selectedState,
                        onAction: handleResultAction
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            await refreshReadiness()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("업무")
                .font(.system(size: 20, weight: .bold))
            Text("필요한 연결을 확인한 뒤 스킬과 업무창으로 이어집니다.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func dashboardSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            content()
        }
    }

    private func state(for descriptor: MyTeamToolDescriptor) -> ToolExecutionState {
        toolStates[descriptor.id] ?? .checkingReadiness
    }

    private func refreshReadiness() async {
        var states: [String: ToolExecutionState] = [:]
        for descriptor in MyTeamToolRegistry.userFacingTools {
            if case .running = toolStates[descriptor.id] {
                states[descriptor.id] = .running
                continue
            }
            states[descriptor.id] = await ToolExecutionRouter.shared.readiness(for: descriptor)
        }
        await MainActor.run {
            toolStates = states
        }
    }

    private func queryBinding(for descriptor: MyTeamToolDescriptor) -> Binding<String>? {
        guard inlineRunnableToolIDs.contains(descriptor.id) else {
            return nil
        }
        return Binding(
            get: { toolQueries[descriptor.id] ?? defaultQuery(for: descriptor) },
            set: { toolQueries[descriptor.id] = $0 }
        )
    }

    private func defaultQuery(for descriptor: MyTeamToolDescriptor) -> String {
        switch descriptor.id {
        case "dart.disclosures.search":
            return "포스코"
        case "news.search":
            return "경제"
        case "weather.current":
            return "서울"
        case "law.search":
            return "근로기준법"
        default:
            return ""
        }
    }

    private func run(_ descriptor: MyTeamToolDescriptor, query: String) {
        Task {
            await MainActor.run {
                toolStates[descriptor.id] = .running
                selectedState = nil
                selectedDescriptor = descriptor
            }
            let input = MyTeamToolInput(
                query: query,
                daysBack: descriptor.id == "dart.disclosures.search" ? 30 : nil,
                displayCount: descriptor.id == "news.search" ? 5 : nil,
                nx: descriptor.id == "weather.current" ? 60 : nil,
                ny: descriptor.id == "weather.current" ? 127 : nil,
                providerHint: descriptor.requiredCredential?.provider
            )
            let result = await ToolExecutionRouter.shared.run(descriptor, input: input)
            await MainActor.run {
                toolStates[descriptor.id] = result
                selectedState = result
                selectedDescriptor = descriptor
            }
        }
    }

    private var inlineRunnableToolIDs: Set<String> {
        [
            "dart.disclosures.search",
            "news.search",
            "weather.current",
            "law.search"
        ]
    }

    private func handleResultAction(_ action: MyTeamNextAction) {
        guard let descriptor = selectedDescriptor else { return }
        switch action.id {
        case "openConnection", "checkConnection":
            onOpenConnection(descriptor.requiredCredential?.provider)
        case "searchAgain", "extendRange", "changeKeyword":
            run(descriptor, query: toolQueries[descriptor.id] ?? defaultQuery(for: descriptor))
        default:
            break
        }
    }
}
