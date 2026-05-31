import SwiftUI

// MARK: - CharacterStoreSkeletonView

/// 캐릭터/워크룸/테마 스토어 스켈레톤 뷰.
/// 실제 StoreKit 결제 없음. 출시 예정 UI 자리만 만듭니다.
/// 기존 캐릭터 역할/말투/성격은 절대 수정하지 않습니다.
struct CharacterStoreSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("캐릭터 & 워크룸", systemImage: "person.2.fill")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    comingSoonBadge
                }
                Text("새로운 캐릭터, 워크룸 테마, 고급 편의 기능을 추가할 수 있어요.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // 플랜 섹션
            VStack(spacing: 10) {
                planCard(
                    icon: "sparkle",
                    title: "기본",
                    subtitle: "기본 캐릭터 4인 포함",
                    isCurrent: true,
                    price: nil
                )
                planCard(
                    icon: "star.fill",
                    title: "캐릭터팩",
                    subtitle: "추가 캐릭터 및 전용 워크룸",
                    isCurrent: false,
                    price: "출시 예정"
                )
                planCard(
                    icon: "paintbrush.fill",
                    title: "테마팩",
                    subtitle: "프리미엄 UI 테마 및 아이콘",
                    isCurrent: false,
                    price: "출시 예정"
                )
            }

            // 안내
            Text("구매 및 결제는 다음 업데이트에서 지원됩니다.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Plan Card

    private func planCard(
        icon: String,
        title: String,
        subtitle: String,
        isCurrent: Bool,
        price: String?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCurrent {
                Text("현재")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            } else if let price {
                Text(price)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent
                      ? Color.accentColor.opacity(0.06)
                      : Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var comingSoonBadge: some View {
        Text("준비 중")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }
}
