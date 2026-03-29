import SwiftUI

// MARK: - AgentSwapView
// 에이전트 교체 창 (스크린샷 참고하여 다크 테마 기반 Grid 형태)
struct AgentSwapView: View {
    let replaceIndex: Int
    let onClose: () -> Void
    
    @EnvironmentObject var manager: AgentWindowManager
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            agentGrid
        }
        .padding(30)
        .frame(width: 800, height: 580)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.05, green: 0.05, blue: 0.08)) // 다크 네이비 배경
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("에이전트 교체")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text("새로운 팀원을 선택하세요")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.bottom, 10)
    }
    
    private var agentGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(manager.allAvailableAgents) { agent in
                    let isActive = manager.activeAgents.contains(where: { $0.id == agent.id })
                    
                    AgentCardView(agent: agent, isActive: isActive)
                        .onTapGesture {
                            // 해당 에이전트로 교체
                            manager.swapAgent(at: replaceIndex, with: agent)
                            onClose()
                        }
                }
                
                addAgentCard
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var addAgentCard: some View {
        // "상점 가기" 역할의 더미 카드 (+)
        Button(action: {
            print("상점 열기 (미구현)")
        }) {
            VStack {
                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
                Text("새 에이전트 고용")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 2, dash: [6])))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - AgentCardView
// 그리드 내 개별 에이전트 카드
struct AgentCardView: View {
    let agent: AgentWindowManager.AgentConfig
    let isActive: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 프로필 이미지 영역
            if !agent.fallbackImageName.isEmpty {
                Image(agent.fallbackImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(agent.emoji)
                    .font(.system(size: 48))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // 정보 영역
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(agent.role)
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
            }
            
            // 하단 태그 (무료/프리미엄 및 활성 상태)
            VStack(alignment: .leading, spacing: 8) {
                Text(agent.isPremium ? "프리미엄" : "무료")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(agent.isPremium ? Color.indigo : Color.orange)
                
                if isActive {
                    Text("활성화됨")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.05))
        )
        // 활성화(선택됨) 상태일 경우 테두리 강조
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.purple.opacity(0.6) : Color.white.opacity(0.05), lineWidth: isActive ? 2 : 1)
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
