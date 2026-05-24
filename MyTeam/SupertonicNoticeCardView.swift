import SwiftUI

// MARK: - SupertonicNoticeCardView
// Round 254TTS-NOTICE: License notice + use restriction card for TTSLabView.
// User must accept before ONNX synthesis is enabled.
// Acceptance does NOT unlock release TTS — lab only.

struct SupertonicNoticeCardView: View {
    @Binding var accepted: Bool
    let onAccept: () -> Void
    let onReset: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {

                // Header
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                    Text("Supertonic TTS 사용 고지")
                        .font(.headline)
                    Spacer()
                    Text("실험 기능")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(5)
                }

                Divider()

                // License notice
                VStack(alignment: .leading, spacing: 6) {
                    Label("라이선스 고지", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Text(SupertonicTTSNoticePolicy.licenseNoticeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Use restrictions
                VStack(alignment: .leading, spacing: 6) {
                    Label("사용 제한", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text(SupertonicTTSNoticePolicy.useRestrictionsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Acceptance state
                if accepted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("현재 고지를 확인했습니다. ONNX 합성 실험이 허용됩니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("고지 수락 초기화") {
                        onReset()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("고지를 확인한 후 ONNX 합성 실험을 사용할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("고지를 확인하고 실험 기능 사용") {
                            onAccept()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .font(.caption)
                    }
                }
            }
            .padding(4)
        }
    }
}
