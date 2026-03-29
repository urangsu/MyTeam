import SwiftUI

// MARK: - AgentMenuPopupView (TeamTableView에서 분리)
struct AgentMenuPopupView: View {
    var isShowing: Bool
    var popupOnLeft: Bool = false // true면 왼쪽에 표시 (4번째 에이전트용)
    var onChat: () -> Void
    var onVoice: () -> Void
    var onSettings: () -> Void
    var onSwap: () -> Void

    var body: some View {
        if isShowing {
            VStack(alignment: .leading, spacing: 0) {
                MenuButton(icon: "message", text: "채팅", action: onChat)
                MenuButton(icon: "mic", text: "음성", action: onVoice)
                Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 8)
                MenuButton(icon: "slider.horizontal.3", text: "추가 설정", action: onSettings)
                MenuButton(icon: "arrow.triangle.2.circlepath", text: "교체", action: onSwap)
            }
            .frame(width: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
            )
            .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
        }
    }

    struct MenuButton: View {
        let icon: String
        let text: String
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray)
                    Text(text).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
