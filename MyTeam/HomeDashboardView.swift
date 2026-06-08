import SwiftUI

struct HomeDashboardView: View {
    let onOpenConnection: (ExternalProvider?) -> Void
    let onOpenWorkspace: (MyTeamToolDescriptor) -> Void

    @State private var toolStates: [String: ToolExecutionState] = [:]

    private let quickToolIDs = [
        "document.meetingMinutes",
        "spreadsheet.postprocess",
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
                                    onOpenWorkspace: onOpenWorkspace,
                                    onOpenConnection: onOpenConnection
                                )
                            }
                        }
                    }
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
            states[descriptor.id] = await ToolExecutionRouter.shared.readiness(for: descriptor)
        }
        await MainActor.run {
            toolStates = states
        }
    }
}
