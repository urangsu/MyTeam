import SwiftUI
import AppKit
#if DEBUG
import StoreKit
#endif

struct CharacterGalleryView: View {
    private let entitlementManager = CharacterEntitlementManager.shared
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("캐릭터 갤러리")
                        .font(.system(size: 20, weight: .bold))
                    Text("내 API 키로 움직이는 AI 팀원입니다. 기본 캐릭터는 포함되어 있고, 프리미엄 캐릭터는 향후 추가 구매로 사용할 수 있습니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("프리미엄 캐릭터는 향후 StoreKit 구매로 해제됩니다. AI 사용량은 기본 제공량을 초과하면 개인 API 키 연결을 권장합니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                section(title: "기본 캐릭터", characters: CharacterCatalog.builtIn)
                section(title: "프리미엄 캐릭터", characters: CharacterCatalog.premium)
            }
            .padding(16)
        }
        .background(Color(NSColor.windowBackgroundColor))
#if DEBUG
        .onAppear {
            CharacterCatalog.validateBuiltInAgentMappings()
            Task {
                await purchaseManager.loadProductsIfNeeded()
            }
        }
#endif
    }

    private func section(title: String, characters: [CharacterDLC]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            if title == "프리미엄 캐릭터" {
                Text("프리미엄 캐릭터는 향후 StoreKit 구매로 해제됩니다. 이번 버전에서는 구매 버튼이 비활성화되어 있습니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(characters) { character in
                    CharacterGalleryCard(
                        character: character,
                        accessState: entitlementManager.accessState(for: character)
                    )
                }
            }

#if DEBUG
            if title == "프리미엄 캐릭터" {
                HStack {
                    Spacer()
                    Button("구매 상태 새로고침") {
                        Task {
                            await purchaseManager.refreshPurchasedProducts()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
#endif
        }
    }
}

private struct CharacterGalleryCard: View {
    let character: CharacterDLC
    let accessState: CharacterAccessState
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                portraitView
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.system(size: 16, weight: .bold))
                    Text(character.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(character.role)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                }
                Spacer()
            }

            Text(character.description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            chipWrap(items: character.specialty, tint: .blue.opacity(0.12), textColor: .blue)
            chipWrap(items: character.bundledSkillIDs.map(skillLabel), tint: .green.opacity(0.12), textColor: .green)

#if DEBUG
            if let agentID = character.agentID {
                Text("연결 예정 agentID: \(agentID)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
#endif

            HStack {
                statusBadge
#if DEBUG
                if isDebugPurchased {
                    debugPurchasedBadge
                }
#endif
                Spacer()
                if let priceDisplay = character.priceDisplay {
                    Text(priceDisplay)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Button(buttonTitle) {
                handleButtonTap()
            }
                .buttonStyle(.borderedProminent)
                .disabled(isActionDisabled)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var portraitView: some View {
        Group {
            if let assetName = character.portraitAssetName,
               let image = NSImage(named: assetName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                    Text(String(character.name.prefix(1)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(statusColor.opacity(0.14)))
    }

    private var statusText: String {
        switch accessState {
        case .owned: return "포함됨"
        case .comingSoon: return "출시 예정"
        case .locked: return "잠김"
        }
    }

    private var statusColor: Color {
        switch accessState {
        case .owned: return .green
        case .comingSoon: return .orange
        case .locked: return .secondary
        }
    }

    private var buttonTitle: String {
#if DEBUG
        if isDebugSenaCharacter {
            if isDebugPurchased {
                return "구매 확인됨"
            }
            if debugProduct != nil {
                return "테스트 구매"
            }
            return "상품 준비 중"
        }
#endif
        switch accessState {
        case .owned: return "사용 가능"
        case .comingSoon: return "출시 예정"
        case .locked: return "구매 준비 중"
        }
    }

    private var isActionDisabled: Bool {
#if DEBUG
        if isDebugSenaCharacter {
            return debugProduct == nil || isDebugPurchased
        }
#endif
        return true
    }

#if DEBUG
    private var isDebugSenaCharacter: Bool {
        character.id == "char.premium.sena" && character.productID == ProductIDCatalog.Character.sena
    }

    private var debugProduct: Product? {
        guard isDebugSenaCharacter, let productID = character.productID else { return nil }
        return purchaseManager.product(for: productID)
    }

    private var isDebugPurchased: Bool {
        guard let productID = character.productID else { return false }
        return purchaseManager.isPurchased(productID)
    }

    private var debugPurchasedBadge: some View {
        Text("구매 확인됨")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.blue.opacity(0.14)))
    }
#else
    private var isDebugPurchased: Bool { false }
#endif

    private func handleButtonTap() {
#if DEBUG
        guard let product = debugProduct, !isDebugPurchased else { return }
        Task {
            do {
                try await purchaseManager.purchase(product)
            } catch {
                AppLog.warning("[StoreKit] sena debug purchase failed: \(error.localizedDescription)")
            }
        }
#endif
    }

    private func chipWrap(items: [String], tint: Color, textColor: Color) -> some View {
        FlexibleChipLayout(items: items, tint: tint, textColor: textColor)
    }

    private func skillLabel(_ id: String) -> String {
        SkillRegistry.shared.builtInSkills().first(where: { $0.id == id })?.name ?? id
    }
}

private struct FlexibleChipLayout: View {
    let items: [String]
    let tint: Color
    let textColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(chunked(items, size: 3), id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(tint))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked(_ values: [String], size: Int) -> [[String]] {
        stride(from: 0, to: values.count, by: size).map {
            Array(values[$0..<min($0 + size, values.count)])
        }
    }
}
