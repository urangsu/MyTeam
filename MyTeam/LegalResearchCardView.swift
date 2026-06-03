import SwiftUI

struct LegalResearchCardView: View {
    let result: KoreanLawResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.lawName)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                statusBadge
            }

            if let article = result.article {
                Text(article)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Text(result.summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            metadataRow

            if !result.mismatchDetails.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("검증 불일치")
                        .font(.system(size: 11, weight: .semibold))
                    ForEach(result.mismatchDetails, id: \.self) { detail in
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                }
            }

            sourceSection

            Text(result.disclaimer)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            if let effectiveDate = result.effectiveDate {
                Label(effectiveDate, systemImage: "calendar")
            }
            Label(result.verificationStatus, systemImage: "checkmark.seal")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("공식 출처")
                .font(.system(size: 11, weight: .semibold))

            if result.sources.isEmpty {
                Text("공식 출처가 확인되지 않았습니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else {
                ForEach(result.sources, id: \.url) { source in
                    Link(source.title, destination: source.url)
                        .font(.system(size: 11))
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(result.status.rawValue.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(statusColor.opacity(0.12)))
    }

    private var statusColor: Color {
        switch result.status {
        case .verified: return .green
        case .partial: return .blue
        case .failed: return .orange
        }
    }

    private var borderColor: Color {
        switch result.status {
        case .verified: return Color.green.opacity(0.20)
        case .partial: return Color.blue.opacity(0.20)
        case .failed: return Color.orange.opacity(0.24)
        }
    }
}
