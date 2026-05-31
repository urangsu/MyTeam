import SwiftUI

struct UsagePolicyCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("이용 안내")
                    .font(.system(size: 14, weight: .semibold))
                Text("MyTeam은 사용자가 연결한 외부 API를 사용합니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                policyRow(
                    icon: "shield.lefthalf.filled",
                    text: "API 키는 이 기기 안에 안전하게 저장됩니다."
                )
                policyRow(
                    icon: "creditcard.slash",
                    text: "요금과 사용량은 해당 서비스 정책을 따릅니다."
                )
                policyRow(
                    icon: "trash",
                    text: "키는 연결 센터에서 언제든 삭제할 수 있습니다."
                )
                policyRow(
                    icon: "person.slash",
                    text: "MyTeam 서버로 키가 전송되지 않습니다."
                )
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

    private func policyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
