import SwiftUI

struct UsagePolicyCardView: View {
    @ObservedObject private var entitlementManager = AppEntitlementManager.shared

    var body: some View {
        let limits = entitlementManager.currentLimits
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Usage Policy")
                    .font(.system(size: 14, weight: .semibold))
                Text("기본 제공량은 온보딩용입니다. 많은 작업은 개인 API 키 연결을 권장합니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                policyRow(title: "현재 플랜", value: entitlementManager.currentPlan.displayName)
                policyRow(title: "Free 기본 제공량", value: "일 \(MonetizationPlanCatalog.free.includedAIMessagesPerDay)회")
                policyRow(title: "Pro 기본 제공량", value: "일 \(MonetizationPlanCatalog.pro.includedAIMessagesPerDay)회 예정")
                policyRow(title: "BYOK", value: BYOKPolicy.isBYOKSupported ? "지원" : "미지원")
                policyRow(title: "개인 키 기본 제공량 소모", value: BYOKPolicy.byokDoesNotConsumeIncludedCredits ? "하지 않음 예정" : "미정")
                policyRow(title: "Pro 결제", value: "준비 중")
                policyRow(title: "활성 에이전트", value: "\(limits.maxActiveAgents)명")
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

    private func policyRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
        }
    }
}
