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

            // Round 241B: disabled(true) 제거, Settings 패널로 연결
            Button(status.isConnected ? "설정 열기" : "API 키 추가") {
                if let url = URL(string: "x-apple.systempreferences:") {
                    // Settings 패널로 이동 (BYOK 전용 UI는 다음 라운드)
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .help(status.isConnected
                  ? "연결된 API 키 설정을 확인합니다."
                  : "API 키 입력 기능은 다음 업데이트에서 제공됩니다. 현재는 설정 앱에서 직접 Keychain을 관리할 수 있습니다."
            )
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
