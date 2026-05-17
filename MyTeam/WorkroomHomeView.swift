import SwiftUI

// MARK: - WorkroomHomeView

struct WorkroomHomeView: View {
    let model: WorkroomHomeModel
    let manager: AgentWindowManager
    let isDarkMode: Bool
    var onPrimaryActionTapped: ((WorkroomPrimaryAction) -> Void)?
    var onNextActionTapped: ((WorkroomNextAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(model.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // MARK: - Current Goal
            if let goal = model.currentGoal, !goal.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("목표")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(goal)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                )
                .padding(.horizontal, 14)
            } else {
                Text("무엇을 정리할까요?")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
            }

            // MARK: - Primary Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("이번엔")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)

                HStack(spacing: 8) {
                    ForEach(model.primaryActions, id: \.self) { action in
                        Button(action: {
                            onPrimaryActionTapped?(action)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: action.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(action.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .foregroundColor(.blue)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
            }

            // MARK: - Recent Artifacts
            if !model.recentArtifacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("최근 결과물")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.recentArtifacts, id: \.id) { artifact in
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue.opacity(0.7))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artifact.filename)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Text(artifact.createdAt)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            // MARK: - Next Actions
            if !model.nextActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("다음 작업")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.nextActions, id: \.self) { action in
                            Button(action: {
                                onNextActionTapped?(action)
                            }) {
                                HStack(spacing: 8) {
                                    Text(action.title)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // Event 1: workroomOpened → greeting/clockIn
            if let roomID = manager.currentRoomID {
                CharacterReactionEventSink.shared.notifyWorkroomOpened(roomID: roomID)
            }
        }
    }
}

#Preview {
    WorkroomHomeView(
        model: .make(
            roomID: UUID(),
            title: "팀 워크룸",
            subtitle: "팀 공간",
            currentGoal: "앱 출시 체크리스트 정리",
            recentArtifacts: [],
            activeTaskSummary: nil
        ),
        manager: AgentWindowManager(),
        isDarkMode: false
    )
}
