import SwiftUI

// MARK: - FileIntakeEventCardView
// Round 243A-OBSERVE: LocalObservation을 사용자에게 보여주는 카드.
//
// 정책:
// - full path 상시 표시 금지
// - raw diagnostic 표시 금지
// - 파일 내용 미리 분석/표시 금지
// - contentKind에 따라 아이콘/문구 표시

struct FileIntakeEventCardView: View {
    let observation: LocalObservation
    let onAttach: (UUID) -> Void    // 이 방에서 분석
    let onIgnore: (UUID) -> Void    // 무시

    var body: some View {
        HStack(spacing: 10) {
            // 아이콘
            Image(systemName: observation.contentKind.systemImageName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            // 설명
            VStack(alignment: .leading, spacing: 2) {
                Text(cardTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(observation.contentKind.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let sizeStr = observation.fileSizeDisplayString {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(sizeStr)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // 액션 버튼
            if observation.isPending {
                HStack(spacing: 6) {
                    Button(attachButtonTitle) {
                        onAttach(observation.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .font(.system(size: 11, weight: .medium))

                    Button("무시") {
                        onIgnore(observation.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: 11))
                }
            } else {
                statusBadge
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var cardTitle: String {
        // displayName만 보여줌 (경로 제외)
        observation.displayName.isEmpty ? "파일을 발견했어요" : observation.displayName
    }

    private var attachButtonTitle: String {
        switch observation.contentKind {
        case .pdf:         return "PDF 읽기"
        case .spreadsheet: return "표 검토"
        case .image:       return "사진 설명"
        case .word:        return "문서 검토"
        case .presentation: return "슬라이드 검토"
        default:           return "이 방에서 분석"
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch observation.status {
        case .userConfirmed, .analyzed:
            Label("분석 중", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .ignored:
            Text("무시됨")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .blocked:
            Label("차단됨", systemImage: "xmark.shield.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        FileIntakeEventCardView(
            observation: LocalObservation(
                source: .downloadsFolder,
                displayName: "2025_결산보고서.pdf",
                contentKind: .pdf,
                fileSizeBytes: 2_048_000
            ),
            onAttach: { _ in },
            onIgnore: { _ in }
        )
        FileIntakeEventCardView(
            observation: LocalObservation(
                source: .clipboard,
                displayName: "클립보드 텍스트",
                contentKind: .text,
                fileSizeBytes: 340
            ),
            onAttach: { _ in },
            onIgnore: { _ in }
        )
        FileIntakeEventCardView(
            observation: LocalObservation(
                roomID: UUID(),
                source: .chatAttachment,
                displayName: "거래내역.csv",
                contentKind: .spreadsheet,
                fileSizeBytes: 85_000,
                status: .userConfirmed
            ),
            onAttach: { _ in },
            onIgnore: { _ in }
        )
    }
    .padding()
    .frame(width: 380)
}
