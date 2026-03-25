import SwiftUI

// MARK: - TeamStatusView
// 고도화: 팀 전체 채팅방(Logs) + 사운드/무음 모드 토글 + 다크모드
struct TeamStatusView: View {
    @EnvironmentObject var manager: AgentWindowManager
    @State private var isCollapsed = false
    @State private var selectedTab: Int = 0 // 0: 에이전트 리스트, 1: 팀 채팅방
    
    private var bgColor: Color {
        manager.isDarkMode ? Color.black.opacity(isCollapsed ? 0.4 : 0.8) : Color.white.opacity(isCollapsed ? 0.3 : 0.75)
    }
    private var textColor: Color {
        manager.isDarkMode ? .white : .black
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── 헤더 (더블 클릭으로 접기/펼치기) ──
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(selectedTab == 0 ? Color.orange : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(selectedTab == 0 ? "팀 협업 중" : "팀 채팅방")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor.opacity(0.8))
                }
                
                Spacer()
                
                HStack(spacing: 14) {
                    // 탭 전환 버튼
                    Button(action: { selectedTab = (selectedTab == 0 ? 1 : 0) }) {
                        Image(systemName: selectedTab == 0 ? "bubble.left.and.bubble.right.fill" : "person.3.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: isCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { manager.hideStatusWindow() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .foregroundColor(manager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isCollapsed.toggle()
                }
            }
            
            if !isCollapsed {
                Divider().background(textColor.opacity(0.05))
                
                if selectedTab == 0 {
                    // ── 탭 0: 에이전트 리스트 ──
                    agentListView
                } else {
                    // ── 탭 1: 팀 채팅방 (로그) ──
                    chatroomView
                }
                
                Divider().background(textColor.opacity(0.05))
                
                // ── 3. 푸터 (다양한 모드 토글) ──
                footerView
            }
        }
        .frame(width: 300, height: isCollapsed ? 40 : 480, alignment: .top)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: isCollapsed ? 20 : 24)
                    .fill(bgColor)
                    .background(
                        RoundedRectangle(cornerRadius: isCollapsed ? 20 : 24)
                            .fill(manager.isDarkMode ? Color.white.opacity(0.05) : Color.blue.opacity(0.03))
                    )
                RoundedRectangle(cornerRadius: isCollapsed ? 20 : 24)
                    .stroke(textColor.opacity(0.2), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(manager.isDarkMode ? 0.3 : 0.08), radius: 15, x: 0, y: 8)
        .padding(10)
    }
    
    // MARK: - 하위 뷰 (에이전트 리스트)
    private var agentListView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 13))
                Text(manager.currentMainTask)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor.opacity(0.6))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider().background(textColor.opacity(0.05))
            
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(manager.activeAgents) { agent in
                        StatusAgentRow(agent: agent, isDarkMode: manager.isDarkMode)
                            .onTapGesture {
                                manager.showChat(for: agent)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - 하위 뷰 (실시간 팀 채팅 로그)
    private var chatroomView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if manager.teamChatLogs.isEmpty {
                        Text("아직 대화 내용이 없습니다.")
                            .font(.system(size: 11))
                            .foregroundColor(textColor.opacity(0.3))
                            .padding(.top, 20)
                    }
                    
                    ForEach(manager.teamChatLogs) { log in
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(log.isUser ? "나" : log.agentName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(log.isUser ? .blue : .orange)
                                Text(log.timestamp, style: .time)
                                    .font(.system(size: 8))
                                    .foregroundColor(textColor.opacity(0.4))
                            }
                            .frame(width: 45, alignment: .trailing)
                            
                            Text(log.text)
                                .font(.system(size: 11))
                                .foregroundColor(textColor.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .id(log.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: manager.teamChatLogs.count) { _, _ in
                if let last = manager.teamChatLogs.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
    
    // MARK: - 하위 뷰 (푸터 토글 및 버튼)
    private var footerView: some View {
        HStack(spacing: 12) {
            // 소리 테마 (음성/무음)
            HStack(spacing: 8) {
                Button(action: { manager.isSilentMode.toggle() }) {
                    Image(systemName: manager.isSilentMode ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(manager.isSilentMode ? .red.opacity(0.6) : .gray.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .help(manager.isSilentMode ? "무음 모드 켬" : "무음 모드 꿈")
                
                Button(action: { manager.isVoiceMode.toggle() }) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundColor(manager.isVoiceMode ? .blue : .gray.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())
                .help(manager.isVoiceMode ? "음성 모드 활성" : "음성 모드 비활성")
            }
            
            Spacer()
            
            // 다크모드 토글
            Button(action: { withAnimation { manager.isDarkMode.toggle() } }) {
                Image(systemName: manager.isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundColor(manager.isDarkMode ? .yellow : .orange.opacity(0.8))
            }
            .buttonStyle(PlainButtonStyle())
            
            // 위치 초기화 버튼 (추가)
            Button(action: { manager.resetWindowPositions() }) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 11))
                    .foregroundColor(.blue.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .help("윈도우 위치 초기화 (중앙으로)")
            
            Button(action: { manager.showSettingsWindow() }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - StatusAgentRow
struct StatusAgentRow: View {
    let agent: AgentWindowManager.AgentConfig
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(agent.color.opacity(isDarkMode ? 0.3 : 0.15)).frame(width: 38, height: 38)
                Text(agent.emoji).font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name).font(.system(size: 13, weight: .semibold)).foregroundColor(isDarkMode ? .white : .black)
                Text(agent.status).font(.system(size: 10)).foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isDarkMode ? .white.opacity(0.2) : .gray.opacity(0.3))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.02))
        )
    }
}
