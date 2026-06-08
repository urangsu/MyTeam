import SwiftUI

struct ToolResultCardView: View {
    let state: ToolExecutionState

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

    private func actionButtons(_ actions: [MyTeamNextAction]) -> some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                if action.role == .normal {
                    Button(action.title) {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(true)
                } else {
                    Button(action.title) {}
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(true)
                }
            }
        }
    }
}
