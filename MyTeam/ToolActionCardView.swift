import SwiftUI

struct ToolActionCardView: View {
    let descriptor: MyTeamToolDescriptor
    let state: ToolExecutionState
    let query: Binding<String>?
    let onRun: ((MyTeamToolDescriptor, String) -> Void)?
    let onOpenWorkspace: (MyTeamToolDescriptor) -> Void
    let onOpenConnection: ((ExternalProvider?) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(descriptor.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        stateBadge
                    }

                    Text(descriptor.shortDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if supportsInlineRun, let query {
                TextField(defaultQuery, text: query)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
            }

            HStack {
                if let provider = descriptor.requiredCredential?.provider {
                    Text(provider.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if case .needsConnection = state {
                    Button("연결", action: { onOpenConnection?(descriptor.requiredCredential?.provider) })
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if case .needsValidation = state {
                    Button("검증", action: { onOpenConnection?(descriptor.requiredCredential?.provider) })
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if case .running = state {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    if state.isRunnable, supportsInlineRun, let query, let onRun {
                        Button(runtimeButtonTitle, action: { onRun(descriptor, query.wrappedValue) })
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(query.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else if state.isRunnable {
                        Button(buttonTitle, action: { onOpenWorkspace(descriptor) })
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else {
                        Button(buttonTitle, action: { onOpenWorkspace(descriptor) })
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(true)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var stateBadge: some View {
        Text(state.displayLabel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private var buttonTitle: String {
        switch descriptor.category {
        case .briefing, .document, .spreadsheet, .externalInfo, .calendar, .mail:
            return "스킬"
        case .voice:
            return "음성"
        case .system:
            return "열기"
        }
    }

    private var supportsInlineRun: Bool {
        descriptor.id == "dart.disclosures.search" || descriptor.id == "news.search"
    }

    private var runtimeButtonTitle: String {
        descriptor.id == "dart.disclosures.search" ? "조회" : "검색"
    }

    private var defaultQuery: String {
        descriptor.id == "dart.disclosures.search" ? "포스코" : "경제"
    }

    private var tint: Color {
        switch state {
        case .idle, .succeeded:
            return .green
        case .needsConnection, .needsValidation, .needsApproval:
            return .orange
        case .failed:
            return .red
        case .running, .checkingReadiness:
            return .blue
        case .unavailable:
            return .secondary
        }
    }

    private var iconName: String {
        switch descriptor.category {
        case .briefing: return "sun.max.fill"
        case .document: return "doc.text.fill"
        case .spreadsheet: return "tablecells.fill"
        case .externalInfo: return "newspaper.fill"
        case .calendar: return "calendar"
        case .mail: return "envelope.fill"
        case .voice: return "waveform"
        case .system: return "gearshape.fill"
        }
    }
}
