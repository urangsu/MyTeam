import Foundation

// MARK: - BeginnerExampleDocumentService
// "예시로 먼저 해보기" 버튼을 위한 local-only 서비스.
// API key 없이도 샘플 회의록을 즉시 생성하고 ArtifactStore에 등록한다.
// 외부 호출 없음 / raw token / sourceText 진단 노출 없음.

@MainActor
final class BeginnerExampleDocumentService {

    static let shared = BeginnerExampleDocumentService()
    private init() {}

    // MARK: - Public API

    /// 샘플 회의록 artifact를 생성하고 ArtifactStore에 등록한다.
    /// - Parameters:
    ///   - roomID: 현재 workroom UUID
    ///   - completion: 성공 시 등록된 IndexedArtifact 반환 (실패 시 nil)
    func generateExampleMeetingMinutes(roomID: UUID) async -> IndexedArtifact? {
        let content = Self.buildExampleMarkdown()
        return await writeAndRegister(
            content: content,
            title: "회의록 예시",
            filename: "회의록_예시_\(Self.dateTag()).md",
            roomID: roomID
        )
    }

    // MARK: - Internal

    private func writeAndRegister(
        content: String,
        title: String,
        filename: String,
        roomID: UUID
    ) async -> IndexedArtifact? {
        let store = ArtifactStore.shared
        let workspaceURL = store.workspaceURL

        let safeFilename = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileURL = workspaceURL.appendingPathComponent(safeFilename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            AppLog.error("BeginnerExampleDocumentService: 파일 쓰기 실패 — \(error.localizedDescription)")
            return nil
        }

        let contentData = content.data(using: .utf8) ?? Data()
        let hash = contentData.map { String(format: "%02x", $0) }.joined().prefix(16)

        let artifact = IndexedArtifact(
            id: UUID().uuidString,
            workflowID: UUID().uuidString,
            title: title,
            type: .report,
            filename: safeFilename,
            relativePath: safeFilename,
            preview: String(content.prefix(200)),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            contentHash: String(hash),
            fileSizeBytes: Int64(contentData.count),
            roomID: roomID.uuidString
        )

        await store.registerArtifact(artifact)

        // workflowCompleted notification → CharacterReactionEventSink → .joy
        let registeredArtifact = artifact
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .workflowCompleted,
                object: nil,
                userInfo: [
                    "workspaceURL": workspaceURL,
                    "artifacts": [registeredArtifact],
                    "workflowID": registeredArtifact.workflowID
                ]
            )
        }

        AppLog.debug("BeginnerExampleDocumentService: '\(title)' 생성 완료")
        return artifact
    }

    // MARK: - Markdown Template

    private static func buildExampleMarkdown() -> String {
        let date = Self.koreanDateString()
        return """
        # 회의록 예시

        **날짜**: \(date)
        **참석자**: 기획팀
        **작성**: 치코 (AI 팀원)

        ---

        ## 회의 목적

        5월 앱 출시 준비 상황을 점검하고 다음 우선순위를 확정한다.

        ---

        ## 논의 내용

        - 온보딩 화면을 먼저 정리하기로 결정했다.
        - 캐릭터 스프라이트는 치코부터 순서대로 제작한다.
        - 스토어 제출 전 QA 체크리스트를 별도로 작성하기로 했다.

        ---

        ## 결정 사항

        | 항목 | 결정 | 담당 |
        |------|------|------|
        | 온보딩 화면 | 3단계 플로우로 확정 | 기획팀 |
        | 캐릭터 스프라이트 | 치코 v1 우선 제작 | 디자인팀 |
        | QA 체크리스트 | 별도 문서로 작성 | 기획팀 |

        ---

        ## 액션아이템

        - [ ] 온보딩 화면 3단계 시나리오 작성
        - [ ] 치코 idle / typing / greeting 스프라이트 의뢰
        - [ ] QA 체크리스트 초안 작성 (스토어 제출 기준)

        ---

        ## 다음 회의

        출시 2주 전 최종 점검 예정

        ---

        *이 문서는 치코가 예시로 만든 회의록입니다.*
        *실제 내용을 붙여넣으면 같은 형식으로 정리해드릴 수 있어요.*
        """
    }

    private static func dateTag() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }

    private static func koreanDateString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: Date())
    }
}
