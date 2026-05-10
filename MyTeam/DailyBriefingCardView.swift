import SwiftUI

struct DailyBriefingCardView: View {
    let briefing: DailyBriefing
    var onActionTap: ((BriefingActionSuggestion) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Text(briefing.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            briefingSection(
                title: "오늘 일정",
                icon: "calendar",
                emptyText: "연결된 일정이 없습니다. Google Calendar 연결 후 오늘 일정을 불러올 수 있습니다."
            ) {
                ForEach(briefing.calendarItems) { item in
                    briefingRow(
                        title: item.title,
                        subtitle: [item.timeText, item.location].compactMap { $0 }.joined(separator: " · "),
                        accent: .blue
                    )
                }
            }

            briefingSection(
                title: "새 메일",
                icon: "envelope",
                emptyText: "Gmail 메타데이터 브리핑은 준비 중입니다. 메일 본문 요약/발송/삭제는 아직 지원하지 않습니다."
            ) {
                ForEach(briefing.mailItems) { item in
                    briefingRow(
                        title: "\(item.sender) · \(item.subject)",
                        subtitle: item.snippet,
                        accent: .orange
                    )
                }
            }

            briefingSection(
                title: "오늘 할 일",
                icon: "checklist",
                emptyText: "오늘 할 일이 아직 없습니다."
            ) {
                ForEach(briefing.taskItems) { item in
                    briefingRow(
                        title: item.title,
                        subtitle: item.dueText ?? "우선순위 \(item.priority)",
                        accent: .green
                    )
                }
            }

            briefingSection(
                title: "확인 필요",
                icon: "exclamationmark.triangle",
                emptyText: "확인 필요 항목이 없습니다."
            ) {
                ForEach(briefing.attentionItems) { item in
                    briefingRow(
                        title: item.title,
                        subtitle: item.detail,
                        accent: attentionAccent(for: item.severity)
                    )
                }
            }

            if !briefing.connectorMessages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("연결 상태")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(briefing.connectorMessages.prefix(3)), id: \.self) { message in
                        Text("• \(message)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if !briefing.actionSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("다음 액션")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 108), spacing: 6)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(Array(briefing.actionSuggestions.prefix(3))) { suggestion in
                            Button {
                                onActionTap?(suggestion)
                            } label: {
                                Text(suggestion.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(.primary)
                                    .background(
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.10))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(suggestion.subtitle ?? suggestion.title)
                        }
                    }
                }
            } else {
                Text("실행 가능한 액션이 아직 없습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.14))
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
            Text(briefing.title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(briefing.status.badgeLabel)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(statusFillColor(for: briefing.status)))
        }
    }

    @ViewBuilder
    private func briefingSection<Content: View>(
        title: String,
        icon: String,
        emptyText: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)

            let hasContent = sectionHasContent(title: title)
            if hasContent {
                content()
            } else {
                Text(emptyText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func briefingRow(title: String, subtitle: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func sectionHasContent(title: String) -> Bool {
        switch title {
        case "오늘 일정": return !briefing.calendarItems.isEmpty
        case "새 메일": return !briefing.mailItems.isEmpty
        case "오늘 할 일": return !briefing.taskItems.isEmpty
        case "확인 필요": return !briefing.attentionItems.isEmpty
        default: return false
        }
    }

    private func statusFillColor(for status: DailyBriefing.Status) -> Color {
        switch status {
        case .unavailable: return Color.gray.opacity(0.12)
        case .empty: return Color.orange.opacity(0.12)
        case .ready: return Color.green.opacity(0.12)
        case .partial: return Color.blue.opacity(0.12)
        case .error: return Color.red.opacity(0.12)
        }
    }

    private func attentionAccent(for severity: DailyAttentionBriefingItem.Severity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .urgent: return .red
        }
    }
}
