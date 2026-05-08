import SwiftUI

struct BYOKProviderCenterView: View {
    private let statuses = BYOKProviderStatusService.loadStatuses()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("API 키 연결")
                    .font(.system(size: 14, weight: .semibold))
                Text("MyTeam은 기본 제공량 이후 사용자의 개인 API 키로 동작할 수 있습니다.")
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

            Button(status.isConnected ? "설정 열기" : "API 키 추가") {}
                .buttonStyle(.bordered)
                .disabled(true)
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
        Text(isConnected ? "연결됨" : "미연결")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(isConnected ? .green : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill((isConnected ? Color.green : Color.secondary).opacity(0.14))
            )
    }
}
