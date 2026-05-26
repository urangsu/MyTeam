import SwiftUI

// Round 250A-255Z: Structured card for KSkillAssistRuntime responses.
// Parses formatMarkdown() output and renders sections with distinct visual treatment.
// Hard-blocked actions section is ALWAYS visible — never inside DisclosureGroup. (Policy)

struct KSkillAssistCardView: View {
    let text: String
    let skillID: String
    let isDarkMode: Bool

    private var sections: KSkillAssistParsedSections {
        KSkillAssistRuntime.parseSections(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider().padding(.horizontal, 12)
            contentView
        }
        .background(cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.teal.opacity(0.35), lineWidth: 1)
        )
        .frame(maxWidth: 500, alignment: .leading)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: intentIcon)
                .foregroundStyle(.teal)
                .font(.system(size: 14, weight: .semibold))
            Text(sections.title.isEmpty ? "K-Skills 도우미" : sections.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDarkMode ? .white : .primary)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        Text(statusBadgeTitle)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(statusBadgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusBadgeColor.opacity(0.12))
            .cornerRadius(4)
    }

    private var statusBadgeTitle: String {
        if !sections.hardBlockedActions.isEmpty { return "안전 안내" }
        if !sections.requiredInputs.isEmpty { return "입력 필요" }
        return "스킬 안내"
    }

    private var statusBadgeColor: Color {
        if !sections.hardBlockedActions.isEmpty { return .red }
        if !sections.requiredInputs.isEmpty { return .blue }
        return .teal
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !sections.message.isEmpty {
                MarkdownTextView(text: sections.message, isDarkMode: isDarkMode)
                    .font(.system(size: 12))
            }

            if isMailAmbiguityCard {
                mailAmbiguityChoiceCard
            }

            if !sections.checklist.isEmpty {
                sectionBlock(
                    icon: "checkmark.square",
                    iconColor: .green,
                    title: "확인 체크리스트",
                    content: {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(sections.checklist, id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "checkmark.square")
                                        .foregroundStyle(.green.opacity(0.8))
                                        .font(.system(size: 11))
                                        .padding(.top, 1)
                                    Text(item)
                                        .font(.system(size: 12))
                                        .foregroundStyle(isDarkMode ? .white.opacity(0.9) : .primary)
                                }
                            }
                        }
                    }
                )
            }

            if !sections.requiredInputs.isEmpty {
                sectionBlock(
                    icon: "info.circle",
                    iconColor: .blue,
                    title: "필요한 정보",
                    content: {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(sections.requiredInputs, id: \.self) { input in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.blue.opacity(0.7))
                                    Text(input)
                                        .font(.system(size: 12))
                                        .foregroundStyle(isDarkMode ? .white.opacity(0.9) : .primary)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.blue.opacity(isDarkMode ? 0.12 : 0.06))
                        .cornerRadius(6)
                    }
                )
            }

            if !sections.nextActions.isEmpty {
                sectionBlock(
                    icon: "arrow.right.circle",
                    iconColor: .teal,
                    title: "다음 단계",
                    content: {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(sections.nextActions.enumerated()), id: \.offset) { idx, action in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(idx + 1).")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.teal.opacity(0.8))
                                        .frame(width: 18, alignment: .trailing)
                                    Text(action)
                                        .font(.system(size: 12))
                                        .foregroundStyle(isDarkMode ? .white.opacity(0.9) : .primary)
                                }
                            }
                        }
                    }
                )
            }

            if !sections.chainStatusLines.isEmpty {
                sectionBlock(
                    icon: "arrow.triangle.branch",
                    iconColor: .blue,
                    title: "실행 체인",
                    content: {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(sections.chainStatusLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11))
                                    .foregroundStyle(isDarkMode ? .white.opacity(0.88) : .primary)
                            }
                        }
                    }
                )
            }

            if !sections.actionSuggestionLines.isEmpty {
                sectionBlock(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "제안 액션",
                    content: {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(sections.actionSuggestionLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11))
                                    .foregroundStyle(isDarkMode ? .white.opacity(0.88) : .primary)
                            }
                        }
                    }
                )
            }

            if !sections.connectorStatusLines.isEmpty {
                sectionBlock(
                    icon: "link",
                    iconColor: .orange,
                    title: "커넥터 상태",
                    content: {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(sections.connectorStatusLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11))
                                    .foregroundStyle(isDarkMode ? .white.opacity(0.82) : .primary)
                            }
                        }
                    }
                )
            }

            if !sections.attachmentStatusLines.isEmpty {
                sectionBlock(
                    icon: "paperclip",
                    iconColor: .green,
                    title: "확인한 첨부",
                    content: {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(sections.attachmentStatusLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11))
                                    .foregroundStyle(isDarkMode ? .white.opacity(0.82) : .primary)
                            }
                        }
                    }
                )
            }

            if !sections.hardBlockedActions.isEmpty {
                hardBlockedSection
            }
        }
        .padding(12)
    }

    // MARK: - Hard-Blocked Actions (always visible, never collapsible)

    private var hardBlockedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.red.opacity(0.8))
                    .font(.system(size: 11))
                Text("직접 대신하지 않는 항목")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(sections.hardBlockedActions, id: \.self) { action in
                    HStack(alignment: .top, spacing: 5) {
                        Text("🚫")
                            .font(.system(size: 10))
                        Text(action)
                            .font(.system(size: 11))
                            .foregroundStyle(isDarkMode ? .red.opacity(0.85) : .red.opacity(0.75))
                    }
                }
            }
        }
        .padding(8)
        .background(Color.red.opacity(isDarkMode ? 0.12 : 0.06))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }

    private var isMailAmbiguityCard: Bool {
        skillID == "korean.mail-summary-assist"
            && sections.message.contains("메일 본문으로 보고")
            && sections.nextActions.contains("메일 본문으로 처리")
    }

    private var mailAmbiguityChoiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 12))
                Text("메일로 처리할지 확인")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDarkMode ? .white : .primary)
            }
            Text("이 문장이 메일 본문인지, 그냥 질문인지 애매해요. 메일 본문으로 보고 요약할까요?")
                .font(.system(size: 12))
                .foregroundStyle(isDarkMode ? .white.opacity(0.86) : .primary.opacity(0.86))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(["메일 본문으로 처리", "메일 본문 붙여넣기", "캡처/파일 올리기"], id: \.self) { title in
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(isDarkMode ? 0.16 : 0.08))
                        .cornerRadius(6)
                }
            }
        }
        .padding(9)
        .background(Color.blue.opacity(isDarkMode ? 0.10 : 0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Section Block Builder

    @ViewBuilder
    private func sectionBlock<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor.opacity(0.8))
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isDarkMode ? .white.opacity(0.6) : .secondary)
            }
            content()
        }
    }

    // MARK: - Helpers

    private var cardBackground: Color {
        isDarkMode ? Color.white.opacity(0.04) : Color.teal.opacity(0.03)
    }

    private var intentIcon: String {
        switch skillID {
        case "korean.ktx-booking": return "tram.fill"
        case "korean.stock-info": return "chart.line.uptrend.xyaxis"
        case "korean.dart": return "doc.text.fill"
        case "korean.map-place", "korean.reservation-preparation": return "map.fill"
        case "korean.naver-news": return "newspaper.fill"
        case "korean.naver-blog-research": return "text.bubble.fill"
        case "korean.law-search": return "building.columns.fill"
        case "korean.scholarship": return "graduationcap.fill"
        case "korean.office-review-assist": return "doc.badge.gearshape.fill"
        case "korean.file-image-assist": return "photo.fill"
        default: return "sparkles"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("KTX Assist Card") {
    let sampleText = KSkillAssistRuntime.formatMarkdown(
        KSkillAssistRuntime.buildAssistResponse(
            intent: .ktxBookingAssist,
            userMessage: "KTX 예매 도와줘"
        )
    )
    return KSkillAssistCardView(
        text: sampleText,
        skillID: "korean.ktx-booking",
        isDarkMode: false
    )
    .padding()
    .frame(width: 500)
}

#Preview("Stock Assist Card (Dark)") {
    let sampleText = KSkillAssistRuntime.formatMarkdown(
        KSkillAssistRuntime.buildAssistResponse(
            intent: .stockInfoAssist,
            userMessage: "삼성전자 주식 정보"
        )
    )
    return KSkillAssistCardView(
        text: sampleText,
        skillID: "korean.stock-info",
        isDarkMode: true
    )
    .padding()
    .frame(width: 500)
    .background(Color.black)
}
#endif
