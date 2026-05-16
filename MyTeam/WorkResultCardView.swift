import SwiftUI

// MARK: - WorkResultCardView
// Round 146A WP2-lite: 긴 어시스턴트 응답(500자+ 또는 마크다운 헤더/표 포함)을
// 260px 말풍선 대신 전체 너비 카드로 렌더링한다.
// 아바타 없음, 말풍선 아님 — 업무 결과물 전용 표시.

struct WorkResultCardView: View {
    let text: String
    let agentName: String
    let agentColor: Color
    let isDarkMode: Bool
    let timestamp: Date?
    var sources: [AgentWindowManager.SourceReference] = []
    var relatedArtifacts: [IndexedArtifact] = []

    @State private var isExpanded: Bool = false

    /// 300자 미리보기 + "더 보기" 토글
    private var previewText: String {
        if text.count <= 500 || isExpanded {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: min(300, text.count))
        return String(text[..<index]) + "…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더: 에이전트 이름 + 시간 (아바타 없음)
            HStack(spacing: 6) {
                Circle()
                    .fill(agentColor.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text(agentName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(agentColor.opacity(0.85))
                Spacer()
                if let ts = timestamp {
                    Text(ts, style: .time)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            // 본문 (마크다운 렌더링)
            MarkdownTextView(
                text: previewText,
                isDarkMode: isDarkMode
            )
            .textSelection(.enabled)

            // 접기/펼치기 토글
            if text.count > 500 {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                        Text(isExpanded ? "접기" : "더 보기")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.blue.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }

            // 출처 칩
            if !sources.isEmpty {
                SourceChipsView(sources: sources, isDarkMode: isDarkMode)
            }

            // 관련 결과물 (inline artifact display)
            if !relatedArtifacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("관련 결과물")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(relatedArtifacts, id: \.id) { artifact in
                        ArtifactCardView(
                            artifact: artifact,
                            compactMode: true
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(agentColor.opacity(0.12), lineWidth: 0.5)
        )
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }) {
                Label("복사", systemImage: "doc.on.doc")
            }
        }
    }

    /// 메시지가 WorkResultCard로 렌더링되어야 하는지 판정
    static func shouldRenderAsWorkResult(_ text: String, isUser: Bool) -> Bool {
        guard !isUser else { return false }
        // 500자 이상
        if text.count >= 500 { return true }
        // 마크다운 헤더 포함
        if text.contains("# ") || text.contains("## ") || text.contains("### ") { return true }
        // 마크다운 표 포함
        if text.contains("|---") || text.contains("| ---") { return true }
        return false
    }
}

#Preview {
    VStack(spacing: 16) {
        WorkResultCardView(
            text: """
            ## 주간 보고서 요약

            ### 1. 진행 현황
            이번 주 완료된 작업은 다음과 같습니다.

            | 항목 | 상태 | 담당자 |
            |---|---|---|
            | UI 리팩터링 | 완료 | 레오 |
            | API 연동 | 진행 중 | 래키 |
            | 테스트 작성 | 대기 | 루나 |

            ### 2. 다음 주 계획
            - API 연동 마무리
            - 통합 테스트 실행
            - 배포 준비
            """,
            agentName: "레오",
            agentColor: .blue,
            isDarkMode: false,
            timestamp: Date()
        )
        Spacer()
    }
    .padding()
}
