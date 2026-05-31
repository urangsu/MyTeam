import SwiftUI

struct BYOKProviderCenterView: View {
    @State private var statuses: [BYOKProviderStatus] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("API 키 연결")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button("상태 새로고침") {
                        reloadStatuses()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Text("연결 센터에서 API 키를 안전하게 연결할 수 있어요. 키는 이 기기에 저장됩니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(statuses) { status in
                    providerRow(status)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
                RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .onAppear(perform: reloadStatuses)
    }

    private func reloadStatuses() {
        statuses = BYOKProviderStatusService.loadStatuses()
    }

    private func providerRow(_ status: BYOKProviderStatus) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(status.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    stateBadge(status.isConnected)
                }
                Text(status.helpText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("저장 위치: \(status.storageLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.85))
            }

            Spacer()

            // "연결 센터" 탭으로 이동 안내
            Text("연결 센터 탭에서 키를 직접 연결하세요")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func stateBadge(_ isConnected: Bool) -> some View {
        Text(isConnected ? "저장됨" : "미연결")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(isConnected ? .green : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill((isConnected ? Color.green : Color.secondary).opacity(0.14))
            )
    }
}
