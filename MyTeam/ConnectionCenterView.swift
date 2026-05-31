import SwiftUI

// MARK: - ConnectionCenterView

/// 연결 센터 — 외부 서비스를 연결하는 메인 허브.
/// 개발자 설정처럼 보이지 않고, 카드형 연결 가이드로 구성됩니다.
struct ConnectionCenterView: View {
    private let profile = AppReleaseProfile.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── 안내 헤더 ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("연결 센터")
                        .font(.system(size: 18, weight: .bold))
                    Text("MyTeam은 연결한 서비스만큼 더 잘 도와드릴 수 있어요.\nAPI 키는 이 기기 안에 안전하게 저장됩니다. MyTeam 서버로 전송되지 않습니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 2)

                // ── AI 모델 ──
                sectionHeader(
                    icon: "sparkles",
                    title: "AI 모델",
                    subtitle: "대화, 문서 작성, 분석에 사용합니다. 하나만 연결해도 충분해요."
                )

                VStack(spacing: 10) {
                    ConnectorSetupCardView(provider: .gemini)
                    ConnectorSetupCardView(provider: .openAI)
                    ConnectorSetupCardView(provider: .anthropic)
                    ConnectorSetupCardView(provider: .openRouter)
                }

                Divider()

                // ── 한국 생활/업무 ──
                sectionHeader(
                    icon: "flag.fill",
                    title: "한국 생활·업무",
                    subtitle: "날씨, 뉴스, 공시를 직접 확인하려면 연결하세요."
                )

                VStack(spacing: 10) {
                    ConnectorSetupCardView(provider: .kmaWeather)
                    ConnectorSetupCardView(provider: .naverNews)
                    ConnectorSetupCardView(provider: .dartDisclosure)
                }

                // ── 고급/개발자 (profile gate) ──
                if profile.policy.allowsExperimentalConnectors {
                    Divider()

                    sectionHeader(
                        icon: "wrench.and.screwdriver",
                        title: "고급 기능",
                        subtitle: "개발자/파워유저용 기능입니다."
                    )

                    VStack(spacing: 10) {
                        PlaywrightMCPSetupCardView()
                    }
                }

                // ── 요금 안내 ──
                requirementNoticeView

                Spacer(minLength: 20)
            }
            .padding(16)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Requirement Notice

    private var requirementNoticeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("요금 및 사용량 안내", systemImage: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("이 기능은 사용자가 연결한 외부 API를 사용합니다.\n요금과 사용량은 해당 서비스 정책을 따르며, MyTeam은 이와 무관합니다.\n키는 언제든 삭제할 수 있습니다.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

// MARK: - PlaywrightMCPSetupCardView

/// Playwright MCP 연결 카드. App Store profile에서는 숨겨집니다.
private struct PlaywrightMCPSetupCardView: View {
    @StateObject private var mcpManager = PlaywrightMCPManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Playwright MCP")
                            .font(.system(size: 13, weight: .semibold))
                        statusBadge
                    }
                    Text("웹 브라우저 자동화 기능입니다. Node.js와 npx가 필요합니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button(action: {
                Task { await MainActor.run { PlaywrightMCPManager.shared.refreshHealth() } }
            }) {
                if mcpManager.isRefreshing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("확인 중...")
                            .font(.system(size: 11))
                    }
                } else {
                    Text("상태 확인")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(mcpManager.isRefreshing)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            if mcpManager.health.initialized { return ("활성", .green) }
            if mcpManager.health.mcpLaunchable { return ("대기", .blue) }
            return ("미설치", .secondary)
        }()
        return Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}
