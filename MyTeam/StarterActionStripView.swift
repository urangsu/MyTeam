import SwiftUI

// MARK: - StarterActionStripView

struct StarterActionStripView: View {
    let actions: [StarterAction]
    var onActionTapped: (StarterAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("시작해보세요")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        StarterActionButton(
                            action: action,
                            onTap: { onActionTapped(action) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - StarterActionButton

struct StarterActionButton: View {
    let action: StarterAction
    var onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(action.emoji)
                        .font(.system(size: 16))
                    Text(action.title)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                Text(action.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(minWidth: 140, minHeight: 60)
            .padding(10)
            .background(isHovering ? Color(.controlAccentColor).opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.controlBorderColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - FirstResultActionStripView

struct FirstResultActionStripView: View {
    let actions: [StarterAction]
    var onActionTapped: (StarterAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("다음 단계")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            HStack(spacing: 6) {
                ForEach(actions.prefix(4)) { action in
                    Button(action: { onActionTapped(action) }) {
                        HStack(spacing: 4) {
                            Text(action.emoji)
                                .font(.system(size: 13))
                            Text(action.title)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.controlBorderColor), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StarterActionStripView(
            actions: StarterActionProvider.actions(for: .empty)
        ) { action in
            print("Tapped: \(action.title)")
        }

        FirstResultActionStripView(
            actions: StarterActionProvider.actionsForFirstResult()
        ) { action in
            print("Tapped: \(action.title)")
        }
    }
    .padding()
}
