import SwiftUI

struct HomeDashboardView: View {
    let onOpenConnection: (ExternalProvider?) -> Void
    let onOpenAssistantConnection: (AssistantConnector.Provider?) -> Void
    let onOpenWorkspace: (MyTeamToolDescriptor) -> Void

    @State private var toolStates: [String: ToolExecutionState] = [:]
    @State private var toolQueries: [String: String] = [
        "briefing.today": "오늘 로컬 업무 브리핑"
    ]
    @State private var selectedState: ToolExecutionState? = nil
    @State private var selectedDescriptor: MyTeamToolDescriptor? = nil
    @State private var pendingApproval: ToolApprovalRequest? = nil
    @StateObject private var executionLogStore = ToolExecutionLogStore.shared

    private var quickTools: [MyTeamToolDescriptor] {
        MyTeamToolRegistry.userFacingTools.filter {
            ProductSurfacePolicy.shouldShowInHomePrimary($0)
        }
    }

    private var connectionTools: [MyTeamToolDescriptor] {
        MyTeamToolRegistry.userFacingTools.filter {
            ProductSurfacePolicy.shouldShowInConnectionSection($0, state: state(for: $0))
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
                        query: queryBinding(for: briefing),
                        onRun: run,
                        onRequestApproval: requestApproval,
                        onOpenWorkspace: onOpenWorkspace,
                        onOpenConnection: onOpenConnection,
                        onOpenAssistantConnection: onOpenAssistantConnection
                    )
                }

                dashboardSection(title: "할 수 있는 것") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                        ForEach(quickTools) { descriptor in
                            ToolActionCardView(
                                descriptor: descriptor,
                                state: state(for: descriptor),
                                query: queryBinding(for: descriptor),
                                onRun: run,
                                onRequestApproval: requestApproval,
                                onOpenWorkspace: onOpenWorkspace,
                                onOpenConnection: onOpenConnection,
                                onOpenAssistantConnection: onOpenAssistantConnection
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
                                    onRequestApproval: requestApproval,
                                    onOpenWorkspace: onOpenWorkspace,
                                    onOpenConnection: onOpenConnection,
                                    onOpenAssistantConnection: onOpenAssistantConnection
                                )
                            }
                        }
                    }
                }

                if let selectedState {
                    ToolResultCardView(
                        state: selectedState,
                        runningTitle: selectedDescriptor?.displayName,
                        onAction: handleResultAction
                    )
                }

                ToolExecutionLogView(store: executionLogStore)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            await refreshReadiness()
        }
        .sheet(item: $pendingApproval) { request in
            ToolApprovalSheetView(
                request: request,
                onCancel: { pendingApproval = nil },
                onApprove: {
                    let descriptor = request.descriptor
                    let query = request.query
                    pendingApproval = nil
                    run(descriptor, query: query, bypassApproval: true)
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("업무")
                .font(.system(size: 20, weight: .bold))
            Text("조회, 정리, 보고 문장까지 하나의 업무 결과로 남깁니다.")
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
            get: { toolQueries[descriptor.id] ?? "" },
            set: { toolQueries[descriptor.id] = $0 }
        )
    }

    private func run(_ descriptor: MyTeamToolDescriptor, query: String) {
        run(descriptor, query: query, bypassApproval: false)
    }

    private func run(_ descriptor: MyTeamToolDescriptor, query: String, bypassApproval: Bool) {
        Task {
            await MainActor.run {
                toolStates[descriptor.id] = .running
                selectedDescriptor = descriptor
                selectedState = .running
            }
            let input = MyTeamToolInput(
                query: query,
                daysBack: descriptor.id == "dart.disclosures.search" ? 30 : nil,
                displayCount: descriptor.id == "news.search" ? 5 : nil,
                providerHint: descriptor.requiredCredential?.provider.externalProvider
            )
            let result = await ToolExecutionRouter.shared.run(descriptor, input: input, bypassApproval: bypassApproval)
            await MainActor.run {
                toolStates[descriptor.id] = result
                selectedState = result
                selectedDescriptor = descriptor
            }
        }
    }

    private func requestApproval(_ descriptor: MyTeamToolDescriptor, query: String, reason: String) {
        pendingApproval = ToolApprovalRequest(
            descriptor: descriptor,
            reason: reason,
            query: query
        )
    }

    private var inlineRunnableToolIDs: Set<String> {
        [
            "dart.disclosures.search",
            "finance.krx.stockPrice",
            "finance.krx.index",
            "finance.company.statement",
            "news.search",
            "weather.current",
            "law.search",
            "briefing.today",
            "document.meetingMinutes",
            "document.rewrite"
        ]
    }

    private func handleResultAction(_ action: MyTeamNextAction) {
        guard let descriptor = selectedDescriptor else { return }
        switch action.id {
        case "openConnection", "checkConnection":
            onOpenConnection(descriptor.requiredCredential?.provider.externalProvider)
        case "openAssistantConnection":
            onOpenAssistantConnection(descriptor.requiredCredential?.provider.assistantProvider)
        case "searchAgain", "extendRange", "changeKeyword":
            run(descriptor, query: toolQueries[descriptor.id] ?? "")
        default:
            break
        }
    }
}
