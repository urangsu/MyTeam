import SwiftUI

// MARK: - WorkroomHomeView

struct WorkroomHomeView: View {
    let model: WorkroomHomeModel
    let manager: AgentWindowManager
    let isDarkMode: Bool
    var onPrimaryActionTapped: ((WorkroomPrimaryAction) -> Void)?
    var onNextActionTapped: ((WorkroomNextAction) -> Void)?
    var onPromptDispatched: ((String) -> Void)?  // 초보자 카드 / 가이드 메시지에서 직접 프롬프트 dispatch

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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

                        // 초보자/고급 모드 토글
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                manager.isBeginnerMode.toggle()
                            }
                        }) {
                            Label(
                                manager.isBeginnerMode ? "간편 모드" : "기본 모드",
                                systemImage: manager.isBeginnerMode ? "sparkles" : "slider.horizontal.3"
                            )
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(manager.isBeginnerMode ? .blue : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(manager.isBeginnerMode
                                          ? Color.blue.opacity(isDarkMode ? 0.2 : 0.08)
                                          : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                if manager.isBeginnerMode {
                    // ─────────────────────────────────────────
                    // MARK: - BEGINNER MODE LAYER
                    // ─────────────────────────────────────────

                    // 치코 안내 메시지
                    BeginnerGuidanceBar(
                        message: guidanceMessage,
                        isDarkMode: isDarkMode
                    ) { prompt in
                        if let p = prompt {
                            onPromptDispatched?(p)
                        } else {
                            // prompt=nil → 파일 선택 안내 (파일 없으면 createDocument로 fallback)
                            onPrimaryActionTapped?(.createDocument)
                        }
                    }

                    // 초보자 업무 카드
                    VStack(alignment: .leading, spacing: 8) {
                        Text("무엇을 시작할까요?")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)

                        VStack(spacing: 8) {
                            ForEach(BeginnerTaskCard.homeCards, id: \.self) { card in
                                BeginnerTaskCardView(card: card, isDarkMode: isDarkMode) { tapped in
                                    handleBeginnerCardTap(tapped)
                                }
                            }

                            // 예시로 시작하기 — 항상 마지막
                            BeginnerTaskCardView(card: .tryExample, isDarkMode: isDarkMode) { tapped in
                                handleBeginnerCardTap(tapped)
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    // 최근 만든 문서 (beginner-friendly 제목)
                    if !model.recentArtifacts.isEmpty {
                        recentDocumentsSection(label: "방금 만든 문서")
                    }

                    // 다음 액션 (artifact 있을 때만)
                    if !model.recentArtifacts.isEmpty && !model.nextActions.isEmpty {
                        nextActionsSection(label: "다음에 할 수 있어요")
                    }

                } else {
                    // ─────────────────────────────────────────
                    // MARK: - STANDARD MODE LAYER
                    // ─────────────────────────────────────────

                    // Current Goal
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

                    // Primary Actions
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

                    // Recent Artifacts
                    if !model.recentArtifacts.isEmpty {
                        recentDocumentsSection(label: "최근 결과물")
                    }

                    // Next Actions
                    if !model.nextActions.isEmpty {
                        nextActionsSection(label: "다음 작업")
                    }
                }

                Spacer(minLength: 16)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if let roomID = manager.currentRoomID {
                CharacterReactionEventSink.shared.notifyWorkroomOpened(roomID: roomID)
            }
        }
    }

    // MARK: - Shared Sub-sections

    @ViewBuilder
    private func recentDocumentsSection(label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
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

    @ViewBuilder
    private func nextActionsSection(label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
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

    // MARK: - Helpers

    /// 초보자 카드 탭 → 적절한 action으로 변환
    private func handleBeginnerCardTap(_ card: BeginnerTaskCard) {
        guard let roomID = manager.currentRoomID else { return }

        if card == .tryExample {
            // tryExample: API key 없어도 local template으로 즉시 생성
            Task {
                await BeginnerExampleDocumentService.shared.generateExampleMeetingMinutes(roomID: roomID)
            }
            CharacterReactionEventSink.shared.notifyDocumentGenerationStarted(
                workflowType: "beginnerExample", roomID: roomID)
            return
        }

        // 그 외 카드: 프롬프트 dispatch
        let prompt = card.dispatchPrompt
        onPromptDispatched?(prompt)

        // Character reaction
        let workflowType = card == .fileSummary ? "fileSummary" : "universalDocument"
        CharacterReactionEventSink.shared.notifyDocumentGenerationStarted(
            workflowType: workflowType, roomID: roomID)
    }

    /// 현재 상태에 맞는 치코 안내 메시지
    private var guidanceMessage: BeginnerGuidanceMessage {
        if model.recentArtifacts.isEmpty {
            return .firstLaunch
        } else {
            return .documentCreated
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
        manager: AgentWindowManager.shared,
        isDarkMode: false
    )
}
