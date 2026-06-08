import SwiftUI

struct HomeDashboardView: View {
    let onOpenConnection: () -> Void

    @State private var toolStates: [String: ToolExecutionState] = [:]
    @State private var selectedState: ToolExecutionState? = nil

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
            VStack(alignment: .leading, spacing: 18) {
                header

                if let briefing = MyTeamToolRegistry.descriptor(id: "briefing.today") {
                    ToolActionCardView(
                        descriptor: briefing,
                        state: state(for: briefing),
                        onRun: { run(briefing) },
                        onOpenConnection: onOpenConnection
                    )
                }

                dashboardSection(title: "빠른 실행", subtitle: "업무명으로 바로 시작합니다.") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                        ForEach(quickTools) { descriptor in
                            ToolActionCardView(
                                descriptor: descriptor,
                                state: state(for: descriptor),
                                onRun: { run(descriptor) },
                                onOpenConnection: onOpenConnection
                            )
                        }
                    }
                }

                dashboardSection(title: "연결 필요", subtitle: "개인 키 저장과 실제 검증을 분리해서 표시합니다.") {
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
                                    onRun: { run(descriptor) },
                                    onOpenConnection: onOpenConnection
                                )
                            }
                        }
                    }
                }

                dashboardSection(title: "최근 실행", subtitle: "실행 기록은 다음 단계에서 연결합니다.") {
                    Text("아직 기록된 실행이 없습니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if let selectedState {
                    ToolResultCardView(state: selectedState)
                }
            }
            .padding(16)
        }
        .task {
            await refreshReadiness()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("수석님, 오늘 업무를 준비했습니다.")
                .font(.system(size: 20, weight: .bold))
            Text("기능을 고르면 MyTeam이 필요한 연결과 승인 상태를 먼저 확인합니다.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func dashboardSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
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

    private func run(_ descriptor: MyTeamToolDescriptor) {
        Task {
            await MainActor.run {
                toolStates[descriptor.id] = .running
            }
            let result = await ToolExecutionRouter.shared.run(descriptor)
            await MainActor.run {
                toolStates[descriptor.id] = result
                selectedState = result
            }
        }
    }
}
