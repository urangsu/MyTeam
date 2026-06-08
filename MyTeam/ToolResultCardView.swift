import SwiftUI
import AppKit

struct ToolResultCardView: View {
    let state: ToolExecutionState
    let onAction: ((MyTeamNextAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state {
            case .succeeded(let result):
                Label(result.title, systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
                Text(result.summary)
                    .font(.system(size: 11))
                if let sourceLabel = result.sourceLabel {
                    Text(sourceLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                resultItems(result.items)
                actionButtons(result.nextActions)
            case .failed(let failure):
                Label(failure.title, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(failure.message)
                    .font(.system(size: 11))
                actionButtons(failure.recoveryActions)
            default:
                Label(state.displayLabel, systemImage: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func resultItems(_ items: [MyTeamToolResultItem]) -> some View {
        VStack(spacing: 6) {
            ForEach(items.prefix(5)) { item in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(2)
                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let metadata = item.metadata, !metadata.isEmpty {
                            Text(metadata)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if let url = item.sourceURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .help("원문 열기")
                    }
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
    }

    private func actionButtons(_ actions: [MyTeamNextAction]) -> some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                if action.role == .normal {
                    Button(action.title) {
                        onAction?(action)
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!isActionEnabled(action))
                } else {
                    Button(action.title) {
                        onAction?(action)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!isActionEnabled(action))
                }
            }
        }
    }

    private func isActionEnabled(_ action: MyTeamNextAction) -> Bool {
        guard onAction != nil else { return false }
        switch action.id {
        case "openConnection", "checkConnection", "searchAgain", "extendRange", "changeKeyword":
            return true
        default:
            return false
        }
    }
}
