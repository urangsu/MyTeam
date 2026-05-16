import SwiftUI

// MARK: - AgentQuickSwitchBar
// 팀원 빠른 이동: 개인 대화로 switch하는 shortcut
// 현재 방의 agentIDs를 mutate하지 않음 (navigation 전용)

struct AgentQuickSwitchBar: View {
    @ObservedObject var manager: AgentWindowManager
    let currentAgentID: String?
    let onSelectAgent: (String) -> Void

    @Environment(\.colorScheme) var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }
    private var bgColor: Color { isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.08) }
    private var textColor: Color { isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12) }

    var body: some View {
        VStack(spacing: 6) {
            Divider().background(textColor.opacity(0.1))

            VStack(alignment: .leading, spacing: 4) {
                Text("팀원")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.4))
                    .padding(.horizontal, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(manager.activeAgents) { agent in
                            Button(action: {
                                onSelectAgent(agent.id)
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(agent.color.opacity(isDarkMode ? 0.3 : 0.15))
                                        .frame(width: 32, height: 32)

                                    Image(agent.fallbackImageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            agent.id == currentAgentID ? agent.color : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .help("\(agent.name)과의 대화")
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .padding(.vertical, 6)
        }
        .background(bgColor)
    }
}

#Preview {
    AgentQuickSwitchBar(
        manager: AgentWindowManager.shared,
        currentAgentID: "agent_1",
        onSelectAgent: { _ in }
    )
    .frame(height: 80)
}
