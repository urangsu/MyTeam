import SwiftUI
import AppKit

struct ChainRunStatusView: View {
    let chainRun: ChainRun
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(chainRun.chainID.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(chainRun.statusSummary)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(statusColor(chainRun.status))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(chainRun.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 16, height: 16)
                            .foregroundStyle(statusColor(step.status))
                            .background(statusColor(step.status).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isDarkMode ? .white : .primary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text(step.status.label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(statusColor(step.status))
                                if let detail = step.detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(isDarkMode ? 0.35 : 0.55))
        .cornerRadius(10)
    }

    private func statusColor(_ status: ChainStepStatus) -> Color {
        switch status {
        case .pending:
            return .secondary
        case .running:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .orange
        }
    }

    private func statusColor(_ status: ChainStatus) -> Color {
        switch status {
        case .pending:
            return .secondary
        case .running:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .blocked:
            return .orange
        }
    }
}
