import Foundation

enum ActionRuntime {
    @MainActor
    static func execute(
        _ action: ActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager
    ) async -> ActionExecutionResult {
        guard let handlerID = action.handlerID else {
            return .queued("핸들러가 연결되지 않은 액션입니다.", prompt: action.title)
        }

        if ApprovalBinder.requiresApproval(for: handlerID) || action.requiresApproval {
            return .approvalNeeded(
                "이 액션은 승인 후 진행됩니다.",
                prompt: action.title,
                handlerID: handlerID
            )
        }

        switch handlerID {
        case .replyDraft:
            let artifactID = await persistDraftArtifact(
                roomID: roomID,
                manager: manager,
                title: action.title,
                stem: "reply-draft",
                body: """
                # 답장 초안

                \(action.preview)

                ## 후속 검토
                - 원문 확인
                - 수신자/기한 확인
                - 승인 후 발송
                """
            )
            return .completed("답장 초안을 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .todoCreate:
            let artifactID = await persistDraftArtifact(
                roomID: roomID,
                manager: manager,
                title: action.title,
                stem: "todo-card",
                body: """
                # 할 일 카드

                \(action.preview)

                ## 체크 포인트
                - 오늘 처리할 항목으로 정리
                - 마감이 있으면 캘린더 제안
                - 완료 후 상태 갱신
                """
            )
            return .completed("할 일 카드를 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .saveMemo:
            let artifactID = await persistDraftArtifact(
                roomID: roomID,
                manager: manager,
                title: action.title,
                stem: "memo",
                body: """
                # 메모

                \(action.preview)

                ## 참고
                - 방 안에서 다시 불러올 수 있도록 저장
                - 다음 질문에서 이어서 사용
                """
            )
            return .completed("메모를 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .createDocument:
            let artifactID = await persistDraftArtifact(
                roomID: roomID,
                manager: manager,
                title: action.title,
                stem: "document",
                body: """
                # 문서 초안

                \(action.preview)

                ## 다음 구성
                - 요약
                - 체크리스트
                - 주의점
                - 승인 후 배포
                """
            )
            return .completed("문서 초안을 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .summarizeArtifact:
            let artifactID = await persistDraftArtifact(
                roomID: roomID,
                manager: manager,
                title: action.title,
                stem: "summary",
                body: """
                # 요약 카드

                \(action.preview)

                ## 검토
                - 원문 근거 확인
                - 수치/날짜 재점검
                - 후속 액션 제안
                """
            )
            return .completed("요약 카드를 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .calendarDraft:
            return .approvalNeeded(
                "캘린더 초안은 승인 후 진행됩니다.",
                prompt: action.preview,
                handlerID: handlerID
            )

        case .openMap:
            return .queued("지도 열기 액션을 준비했습니다.", prompt: action.preview, handlerID: handlerID)

        case .openBooking:
            return .approvalNeeded(
                "예약/예매는 승인 후 진행됩니다.",
                prompt: action.preview,
                handlerID: handlerID
            )
        }
    }

    private static func persistDraftArtifact(
        roomID: UUID,
        manager: AgentWindowManager,
        title: String,
        stem: String,
        body: String
    ) async -> String? {
        let workflowID = manager.currentWorkflowID ?? UUID()
        let context = ToolExecutionContext.current(workflowID: workflowID, roomID: roomID)
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .short,
            timeStyle: .short
        )
        let filename = "\(stem)-\(workflowID.uuidString.prefix(8))-\(UUID().uuidString.prefix(6)).md"

        do {
            let url = try safeWritableWorkspaceURL(filename: filename, context: context)
            let payload = """
            # \(title)

            \(body)

            ---
            생성 시각: \(timestamp)
            방 ID: \(roomID.uuidString)
            """
            try payload.write(to: url, atomically: true, encoding: .utf8)

            let savedFilename = url.lastPathComponent
            let preview = String(payload.prefix(220)).replacingOccurrences(of: "\n", with: " ")
            let artifact = IndexedArtifact(
                id: UUID().uuidString,
                workflowID: workflowID.uuidString,
                title: title,
                type: .text,
                filename: savedFilename,
                relativePath: savedFilename,
                preview: preview,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                contentHash: StableContentHash.sha256Hex(payload),
                fileSizeBytes: Int64(payload.utf8.count),
                roomID: roomID.uuidString
            )

            await ArtifactStore.shared.registerArtifact(artifact)
            manager.addRecentArtifactIndexEntry(
                RecentArtifactIndexEntry(
                    artifactID: artifact.id,
                    roomID: roomID,
                    filename: savedFilename,
                    artifactType: artifact.type.rawValue,
                    createdAt: Date(),
                    contentHash: artifact.contentHash,
                    fileSizeBytes: artifact.fileSizeBytes
                )
            )
            ChainRunStore.shared.appendArtifact(artifact.id, roomID: roomID)
            return artifact.id
        } catch {
            AppLog.error("[ActionRuntime] artifact write failed: \(error.localizedDescription)")
            return nil
        }
    }
}
