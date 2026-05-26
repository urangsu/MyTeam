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
