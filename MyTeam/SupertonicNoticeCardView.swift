import SwiftUI

struct SupertonicNoticeCardView: View {
    let accepted: Bool
    let onAccept: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: accepted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(accepted ? .green : .orange)
                Text("Supertonic3 실험 고지")
                    .font(.headline)
                Spacer()
                Text(accepted ? "수락됨" : "필수")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accepted ? .green : .orange)
            }

            Text("이 영역은 목소리 연구용입니다. 모델/런타임/배포 gate가 닫혀 있으면 실제 합성은 실행하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(accepted ? "다시 확인" : "고지 수락") { onAccept() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button("수락 초기화") { onReset() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!accepted)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
