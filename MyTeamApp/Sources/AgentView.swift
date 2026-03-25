import SwiftUI
import AppKit

// MARK: - AgentView
// 투명 창 안에 렌더링될 캐릭터 뷰입니다.
// Phase 1에서는 이모지로 캐릭터를 대신하며,
// Phase 4에서 Rive 애니메이션으로 교체됩니다.
struct AgentView: View {

    let agentID: String
    let agentName: String
    let emoji: String          // 임시 캐릭터 (나중에 Rive로 교체)
    let color: Color

    // 드래그 상태 (Phase 1-C에서 완성)
    @State private var isDragging: Bool = false
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 8) {

            // ── 캐릭터 이모지 (임시) ──
            Text(isDragging ? "😵" : emoji)
                .font(.system(size: 80))
                .rotationEffect(isDragging ? .degrees(-15) : .degrees(0))
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isDragging)
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)

            // ── 에이전트 이름 배지 ──
            Text(agentName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.85))
                        .shadow(color: color.opacity(0.5), radius: 4)
                )

            // ── 상태 표시 점 (말하는 중 / 생각 중 / 대기) ──
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("대기 중")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: 220, height: 260)
        .background(Color.clear)             // 배경 투명 유지
        .contentShape(Rectangle())           // 클릭 영역 지정
        // 드래그 제스처 (창 이동) — Phase 1-C에서 확장 예정
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in
                    if !isDragging {
                        isDragging = true
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

// MARK: - Preview
#Preview {
    AgentView(
        agentID: "agent_1",
        agentName: "Alex (PM)",
        emoji: "🧑‍💼",
        color: .blue
    )
    .frame(width: 220, height: 280)
    .background(Color.black.opacity(0.3))
}
