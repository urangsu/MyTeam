import SwiftUI

struct ToolExecutionLogView: View {
    @ObservedObject var store: ToolExecutionLogStore
    @State private var showsAllEntries = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("최근 실행")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !store.entries.isEmpty {
                    Button("지우기") {
                        store.clear()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if store.entries.isEmpty {
                Text("아직 실행 기록이 없습니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(store.entries.prefix(3)) { entry in
                        logRow(entry)
                    }

                    if store.entries.count > 3 {
                        DisclosureGroup(isExpanded: $showsAllEntries) {
                            VStack(spacing: 6) {
                                ForEach(store.entries.dropFirst(3)) { entry in
                                    logRow(entry)
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            Text("전체 보기 \(store.entries.count)건")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func logRow(_ entry: ToolExecutionLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName(for: entry.state))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint(for: entry.state))
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(label(for: entry.state))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tint(for: entry.state))
                }

                Text(detail(for: entry))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func detail(for entry: ToolExecutionLogEntry) -> String {
        if let failure = entry.failureMessage, !failure.isEmpty {
            return failure
        }
        if let summary = entry.resultSummary, !summary.isEmpty {
            return summary
        }
        if let provider = entry.provider {
            return "\(provider.displayName) · \(entry.permissionLevel.rawValue)"
        }
        return entry.permissionLevel.rawValue
    }

    private func iconName(for state: ToolExecutionLogState) -> String {
        switch state {
        case .running: return "clock"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .blocked: return "lock.fill"
        }
    }

    private func label(for state: ToolExecutionLogState) -> String {
        switch state {
        case .running: return "실행 중"
        case .succeeded: return "완료"
        case .failed: return "실패"
        case .blocked: return "차단"
        }
    }

    private func tint(for state: ToolExecutionLogState) -> Color {
        switch state {
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .orange
        case .blocked: return .secondary
        }
    }
}
