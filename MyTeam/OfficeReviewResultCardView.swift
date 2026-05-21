import SwiftUI

// Round 248A-OFFICE-LITE: Office review result card displaying heuristic-based findings
// with explicit limitations disclaimer. No evidence location tracking, no original file mutation.

struct OfficeReviewResultCardView: View {
    let result: OfficeReviewLiteExecutor.ReviewResult
    let isExpanded: Bool
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.system(.body, design: .default))
                        .fontWeight(.semibold)
                    Text(result.summary)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: onExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onExpand)

            if isExpanded {
                Divider()

                // Issues section
                if !result.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("발견 사항")
                            .font(.system(.caption, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)

                        ForEach(result.issues.indices, id: \.self) { idx in
                            let issue = result.issues[idx]
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .center) {
                                    Circle()
                                        .fill(issueSeverityColor(issue.severity))
                                        .frame(width: 6, height: 6)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.text)
                                        .font(.system(.caption, design: .default))
                                    if !issue.evidence.isEmpty {
                                        Text("위치: \(issue.evidence)")
                                            .font(.system(.caption2, design: .default))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }

                // Action items section
                if !result.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("추천 조치")
                            .font(.system(.caption, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)

                        ForEach(result.actionItems.indices, id: \.self) { idx in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.system(.caption, design: .default))
                                Text(result.actionItems[idx])
                                    .font(.system(.caption, design: .default))
                                Spacer()
                            }
                        }
                    }
                }

                // Limitations section (always shown, required by policy)
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("휴리스틱 기반 결과")
                                .font(.system(.caption, design: .default))
                                .fontWeight(.semibold)
                        }
                        ForEach(result.limitations.indices, id: \.self) { idx in
                            HStack(alignment: .top, spacing: 6) {
                                Text("–")
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.gray)
                                Text(result.limitations[idx])
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(6)
                }

                // Next steps section
                if !result.suggestedNextSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("다음 단계")
                            .font(.system(.caption, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)

                        ForEach(result.suggestedNextSteps.indices, id: \.self) { idx in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(idx + 1).")
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.gray)
                                Text(result.suggestedNextSteps[idx])
                                    .font(.system(.caption, design: .default))
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func issueSeverityColor(_ severity: String) -> Color {
        switch severity {
        case "critical": return .red
        case "warning": return .orange
        default: return .blue
        }
    }
}

#Preview {
    let sample = OfficeReviewLiteExecutor.ReviewResult(
        skillID: "office-review.meeting-action-items",
        title: "회의록 액션아이템",
        summary: "총 3개의 액션아이템을 추출했습니다.",
        issues: [],
        actionItems: [
            "Q2 실적 분석 자료 준비 (김철수)",
            "고객 피드백 정리 및 분석 (이영희)",
            "신규 기획안 검토 및 의견 제출 (박민준)"
        ],
        limitations: [
            "휴리스틱 기반 추출: 키워드(확인·준비·검토 등)로 후보를 식별합니다.",
            "근거 위치 추적 미지원: 원문에서 정확한 위치를 표시하지 않습니다."
        ],
        suggestedNextSteps: [
            "추출된 액션아이템을 검토하고 필요시 수정해 주세요.",
            "담당자와 기한을 명시해 추적 템플릿을 작성하시길 권장합니다."
        ]
    )

    VStack {
        OfficeReviewResultCardView(result: sample, isExpanded: false) {}
            .padding()
        Spacer()
    }
}
