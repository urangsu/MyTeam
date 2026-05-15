import SwiftUI

// MARK: - StarterActionStripView
// 4개의 starter action을 UI 버튼으로 표시

struct StarterActionStripView: View {
    let actions: [StarterAction]
    let onActionTap: (StarterAction) -> Void

    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("시작하기")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)

            VStack(spacing: 10) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { _, action in
                    actionButton(for: action)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color(nsColor: NSColor.controlBackgroundColor) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func actionButton(for action: StarterAction) -> some View {
        Button(action: { onActionTap(action) }) {
            HStack(spacing: 12) {
                Text(action.emoji)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(action.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.05))
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - FirstResultActionStripView
// 첫 artifact 생성 후 보여줄 활성화 액션

struct FirstResultActionStripView: View {
    let actions: [StarterAction]
    let onActionTap: (StarterAction) -> Void

    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("다음 단계")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)

            VStack(spacing: 10) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { _, action in
                    actionButton(for: action)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color(nsColor: NSColor.controlBackgroundColor) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func actionButton(for action: StarterAction) -> some View {
        Button(action: { onActionTap(action) }) {
            HStack(spacing: 12) {
                Text(action.emoji)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(action.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.05))
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 20) {
        StarterActionStripView(
            actions: StarterActionProvider.actions(),
            onActionTap: { _ in }
        )

        FirstResultActionStripView(
            actions: StarterActionProvider.actionsForFirstResult(),
            onActionTap: { _ in }
        )

        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}
