import SwiftUI

// MARK: - BeginnerTaskCardView
// 초보자용 업무 카드.
// 사용자가 할 일 / 치코가 할 일로 분리해 신뢰감을 주고 프롬프트를 몰라도 시작할 수 있게 한다.

struct BeginnerTaskCardView: View {
    let card: BeginnerTaskCard
    let isDarkMode: Bool
    var onTap: ((BeginnerTaskCard) -> Void)?

    @State private var isExpanded: Bool = false

    private var bgColor: Color {
        isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    private var borderColor: Color {
        card == .tryExample
            ? Color.blue.opacity(isDarkMode ? 0.5 : 0.3)
            : Color.clear
    }

    var body: some View {
        Button(action: {
            onTap?(card)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Card Header ──
                HStack(spacing: 10) {
                    Image(systemName: card.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(card == .tryExample ? .blue : .primary.opacity(0.7))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(card.subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    // 예시로 시작하기는 강조 화살표, 나머지는 일반
                    Image(systemName: card == .tryExample ? "arrow.right.circle.fill" : "arrow.right")
                        .font(.system(size: card == .tryExample ? 16 : 10, weight: .semibold))
                        .foregroundColor(card == .tryExample ? .blue : .secondary.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                // ── Role Split (expand on hover/tap on info) — 탭 한 번은 dispatch, 여기선 정보만 표시 ──
                if card != .tryExample {
                    Divider()
                        .background(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                        .padding(.horizontal, 12)

                    HStack(alignment: .top, spacing: 12) {
                        // 사용자가 할 일
                        VStack(alignment: .leading, spacing: 3) {
                            Text("내가 할 일")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(card.userTasks, id: \.self) { task in
                                HStack(alignment: .top, spacing: 4) {
                                    Text("•")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(task)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 치코가 할 일
                        VStack(alignment: .leading, spacing: 3) {
                            Text("치코가 할 일")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.blue.opacity(0.7))
                            ForEach(card.chikoTasks, id: \.self) { task in
                                HStack(alignment: .top, spacing: 4) {
                                    Text("✦")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue.opacity(0.5))
                                    Text(task)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - BeginnerGuidanceBar
// WorkroomHomeView 상단에 치코의 안내 문구를 표시하는 뷰.
// 상황에 맞는 BeginnerGuidanceMessage를 받아 렌더링한다.

struct BeginnerGuidanceBar: View {
    let message: BeginnerGuidanceMessage
    let isDarkMode: Bool
    var onPrimaryAction: ((String?) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // 치코 아이콘 자리
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(isDarkMode ? 0.2 : 0.08))
                        .frame(width: 28, height: 28)
                    Text("🐾")
                        .font(.system(size: 14))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(message.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(message.body)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Button(action: {
                onPrimaryAction?(message.prompt)
            }) {
                Text(message.primaryActionTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(isDarkMode ? 0.15 : 0.07))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 36)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.blue.opacity(0.03))
        )
        .padding(.horizontal, 14)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        BeginnerGuidanceBar(
            message: .firstLaunch,
            isDarkMode: false
        )
        BeginnerTaskCardView(
            card: .meetingMinutes,
            isDarkMode: false
        )
        BeginnerTaskCardView(
            card: .tryExample,
            isDarkMode: false
        )
    }
    .padding()
    .frame(width: 360)
}
