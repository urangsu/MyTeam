import Foundation

enum ActionRuntime {
    @MainActor
    static func execute(
        _ action: ActionSuggestion,
        roomID: UUID,
        manager: AgentWindowManager,
        chainRunID: UUID? = nil
    ) async -> ActionExecutionResult {
        guard let handlerID = action.handlerID else {
            return .failed("핸들러가 연결되지 않은 액션입니다.", failureCode: "missing_handler")
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
            guard let artifactID = await persistDraftArtifact(
                roomID: roomID,
                chainRunID: chainRunID ?? action.chainRunID,
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
            ) else {
                return .failed("artifact 저장에 실패했습니다.", handlerID: handlerID, failureCode: "artifact_write_failed")
            }
            return .completed("답장 초안을 방 안의 문서 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .todoCreate:
            guard let artifactID = await persistDraftArtifact(
                roomID: roomID,
                chainRunID: chainRunID ?? action.chainRunID,
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
            ) else {
                return .failed("artifact 저장에 실패했습니다.", handlerID: handlerID, failureCode: "artifact_write_failed")
            }
            return .completed("할 일 카드를 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .saveMemo:
            guard let artifactID = await persistDraftArtifact(
                roomID: roomID,
                chainRunID: chainRunID ?? action.chainRunID,
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
            ) else {
                return .failed("artifact 저장에 실패했습니다.", handlerID: handlerID, failureCode: "artifact_write_failed")
            }
            return .completed("메모를 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .createDocument:
            guard let artifactID = await persistDraftArtifact(
                roomID: roomID,
                chainRunID: chainRunID ?? action.chainRunID,
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
            ) else {
                return .failed("artifact 저장에 실패했습니다.", handlerID: handlerID, failureCode: "artifact_write_failed")
            }
            return .completed("문서 초안을 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .summarizeArtifact:
            guard let artifactID = await persistDraftArtifact(
                roomID: roomID,
                chainRunID: chainRunID ?? action.chainRunID,
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
            ) else {
                return .failed("artifact 저장에 실패했습니다.", handlerID: handlerID, failureCode: "artifact_write_failed")
            }
            return .completed("요약 카드를 방 안의 artifact로 저장했습니다.", handlerID: handlerID, artifactID: artifactID)

        case .calendarDraft:
            return .approvalNeeded(
                "캘린더 초안 카드는 승인 후 진행됩니다.",
                prompt: action.title,
                handlerID: handlerID
            )

        case .openMap:
            return .queued("지도 검색어를 준비했습니다.", prompt: action.preview, handlerID: handlerID)

        case .openBooking:
            return .prepared("예매를 완료한 것이 아니라, 검색 조건을 준비했습니다.", prompt: action.preview, handlerID: handlerID)
        }
    }

    @MainActor
    private static func persistDraftArtifact(
        roomID: UUID,
        chainRunID: UUID?,
        manager: AgentWindowManager,
        title: String,
        stem: String,
        body: String
    ) async -> String? {
        guard let chainRunID else { return nil }
        let workflowID = ArtifactWorkflowOwnership.workflowID(for: roomID, manager: manager)
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
                chainRunID: chainRunID.uuidString,
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

            switch await ArtifactStore.shared.registerArtifact(artifact) {
            case .success:
                break
            case .failure(let error):
                try? FileManager.default.removeItem(at: url)
                AppLog.error("[ActionRuntime] artifact index registration failed: \(error)")
                return nil
            }
            ChainRunStore.shared.appendArtifact(artifact.id, chainRunID: chainRunID, roomID: roomID)
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
            return artifact.id
        } catch {
            AppLog.error("[ActionRuntime] artifact write failed: \(error.localizedDescription)")
            return nil
        }
    }
}
