import Foundation

struct ChainSourceReference: Identifiable, Codable, Sendable, Hashable {
    var id: UUID = UUID()
    let title: String
    let provider: String
    let url: String
    let accessedAt: Date
    let sourceType: AgentWindowManager.SourceType

    init(
        id: UUID = UUID(),
        title: String,
        provider: String,
        url: String,
        accessedAt: Date,
        sourceType: AgentWindowManager.SourceType? = nil
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.url = url
        self.accessedAt = accessedAt
        self.sourceType = sourceType ?? AgentWindowManager.inferredSourceType(provider: provider, title: title, url: url)
    }
}

struct ChainRun: Identifiable, Codable, Sendable {
    let id: UUID
    let roomID: UUID
    let chainID: SkillChainID
    var steps: [ChainStep]
    var status: ChainStatus
    var sources: [ChainSourceReference]
    var actions: [ActionSuggestion]
    var artifacts: [String]
    var startedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        roomID: UUID,
        chainID: SkillChainID,
        steps: [ChainStep],
        status: ChainStatus = .running,
        sources: [ChainSourceReference] = [],
        actions: [ActionSuggestion] = [],
        artifacts: [String] = [],
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.roomID = roomID
        self.chainID = chainID
        self.steps = steps
        self.status = status
        self.sources = sources
        self.actions = actions
        self.artifacts = artifacts
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    var stepStatusLines: [String] {
        steps.enumerated().map { index, step in
            let prefix: String
            switch step.status {
            case .pending:
                prefix = "·"
            case .running:
                prefix = "▶"
            case .succeeded:
                prefix = "✓"
            case .failed:
                prefix = "✕"
            case .skipped:
                prefix = "↷"
            }
            var pieces = ["\(index + 1). \(prefix) \(step.title) [\(step.status.label)]"]
            if let connectorID = step.connectorID, !connectorID.isEmpty {
                pieces.append("connector=\(connectorID)")
            }
            if let durationText = step.durationText {
                pieces.append("duration=\(durationText)")
            }
            if let summary = step.outputSummary, !summary.isEmpty {
                pieces.append("output=\(summary)")
            }
            if let failureDetail = step.failureDetail, !failureDetail.isEmpty {
                pieces.append("failure=\(Self.userFacingFailureMessage(for: failureDetail))")
            }
            if !step.sourceIDs.isEmpty {
                pieces.append("sources=\(step.sourceIDs.count)")
            }
            return pieces.joined(separator: " · ")
        }
    }

    var statusSummary: String {
        switch status {
        case .pending:
            return "대기"
        case .running:
            return "실행 중"
        case .succeeded:
            return "성공"
        case .failed:
            return "실패"
        case .blocked:
            return "차단"
        }
    }

    var sourceSummary: String {
        guard !sources.isEmpty else { return "출처 없음" }
        let sourceTypes = Array(Set(sources.map(\.sourceType.rawValue))).sorted()
        let sourceText = sourceTypes.prefix(3).joined(separator: " · ")
        return "\(sources.count)개 출처\(sourceText.isEmpty ? "" : " · \(sourceText)")"
    }

    var actionSummary: String {
        guard !actions.isEmpty else { return "다음 액션 없음" }
        return "\(actions.count)개 액션"
    }

    var artifactSummary: String {
        guard !artifacts.isEmpty else { return "artifact 없음" }
        return "\(artifacts.count)개 artifact"
    }

    static func userFacingFailureMessage(for detail: String) -> String {
        let normalized = detail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "quote_unverified":
            return "시세 출처를 확인하지 못했어요."
        case "quote_connector_unavailable":
            return "시세 조회 커넥터를 아직 사용할 수 없어요."
        case "news_unverified":
            return "뉴스 근거를 아직 확인하지 못했어요."
        case "news_connector_unavailable":
            return "뉴스 검색 커넥터를 아직 사용할 수 없어요."
        case "disclosure_unverified":
            return "공시 근거를 아직 확인하지 못했어요."
        case "disclosure_connector_unavailable":
            return "공시 검색 커넥터를 아직 사용할 수 없어요."
        case "insufficient_concrete_sources":
            return "뉴스나 공시 근거가 부족해서 원인을 단정하지 않았어요."
        case "insufficient_causal_sources":
            return "원인 후보를 만들 근거가 충분하지 않아요."
        case "stock_quote_only":
            return "시세는 확인했지만 뉴스나 공시 근거가 부족해 원인을 단정하지 않았어요."
        case "market_context_unverified":
            return "시장 맥락 출처를 확인하지 못했어요."
        case "web_fetch_unavailable":
            return "웹 조회 커넥터를 아직 사용할 수 없어요."
        case "mail_body_ambiguous":
            return "메일 원문으로 보기엔 짧아요. 본문인지 먼저 확인해야 해요."
        case "mail_body_missing", "mail_source_missing":
            return "메일 본문이 아직 없어요."
        case "ocr_needed":
            return "텍스트 추출이나 OCR이 필요해요."
        case "document_type_unavailable":
            return "문서 유형을 확정할 수 없어요."
        case "no_attachment":
            return "첨부 파일이 필요해요."
        case "train_connector_unavailable":
            return "열차 조회 커넥터를 아직 사용할 수 없어요."
        case "map_connector_unavailable":
            return "지도 이동 시간 커넥터를 아직 사용할 수 없어요."
        case "trip_sources_unavailable":
            return "이동 후보를 만들 근거가 충분하지 않아요."
        case "no_public_sources":
            return "공개 출처를 찾지 못했어요."
        default:
            return detail
        }
    }
}

struct ChainRuntimeSmokeCaseResult: Codable, Sendable, Hashable {
    let name: String
    let input: String
    let chainID: String?
    let chainStatus: String?
    let verificationStatus: String?
    let sourceTypes: [String]
    let stepStatuses: [String]
    let renderStockMoveCardSucceeded: Bool
    let issues: [String]
}

enum ChainRuntimeSmokeSuite {
    struct SmokeCase: Sendable {
        let name: String
        let message: String
        let attachments: [ChatAttachment]
    }

    static let cases: [SmokeCase] = [
        SmokeCase(name: "stock-degraded-connector", message: "삼성전자 왜 떨어졌어?", attachments: []),
        SmokeCase(name: "stock-no-quote-source", message: "이 종목 왜 떨어졌어?", attachments: []),
        SmokeCase(name: "stock-quote-news", message: "현대차 오늘 왜 올랐어?", attachments: []),
        SmokeCase(name: "stock-drop", message: "삼성전자 왜 떨어졌어?", attachments: []),
        SmokeCase(name: "stock-rally", message: "현대차 오늘 왜 올랐어?", attachments: []),
        SmokeCase(name: "stock-impact", message: "엔비디아 관련해서 SK하이닉스 영향 있어?", attachments: []),
        SmokeCase(name: "mail-command-only", message: "이 메일 정리해줘", attachments: []),
        SmokeCase(name: "mail-ambiguous", message: "내일 3시에 회의 가능하실까요?", attachments: []),
        SmokeCase(name: "mail-body", message: "이 메일 정리해줘", attachments: [
            ChatAttachment(
                fileName: "mail.txt",
                fileSize: 128,
                type: .text,
                textContent: """
                안녕하세요.
                내일 3시에 회의 가능하실까요?
                가능하시면 장소도 함께 알려주세요.
                감사합니다.
                """,
                localPath: nil
            )
        ]),
        SmokeCase(name: "document-no-text", message: "이 PDF 정리해줘", attachments: [
            ChatAttachment(
                fileName: "scan.pdf",
                fileSize: 2048,
                type: .pdf,
                textContent: nil,
                localPath: nil
            )
        ]),
        SmokeCase(name: "document-image-no-ocr", message: "이 캡처 정리해줘", attachments: [
            ChatAttachment(
                fileName: "capture.png",
                fileSize: 2048,
                type: .image,
                textContent: nil,
                localPath: nil
            )
        ]),
        SmokeCase(name: "document-pdf-with-text", message: "이 PDF 정리해줘", attachments: [
            ChatAttachment(
                fileName: "notice.pdf",
                fileSize: 4096,
                type: .pdf,
                textContent: "제출 마감은 2026년 6월 10일이며 담당자는 운영팀입니다. 총 금액은 120,000원입니다.",
                localPath: nil
            )
        ]),
        SmokeCase(name: "action-artifact-write-fail", message: "메일 답장 초안 만들어줘", attachments: []),
        SmokeCase(name: "action-chain-run-id-missing", message: "할 일 카드로 저장해줘", attachments: [])
    ]

    static func run() async -> [ChainRuntimeSmokeCaseResult] {
        var results: [ChainRuntimeSmokeCaseResult] = []
        for testCase in cases {
            let roomID = UUID()
            guard let route = await KSkillRunEngine.runPrimary(
                userMessage: testCase.message,
                roomID: roomID,
                attachments: testCase.attachments
            ) else {
                results.append(
                    ChainRuntimeSmokeCaseResult(
                        name: testCase.name,
                        input: testCase.message,
                        chainID: nil,
                        chainStatus: nil,
                        verificationStatus: nil,
                        sourceTypes: [],
                        stepStatuses: [],
                        renderStockMoveCardSucceeded: false,
                        issues: ["Skill route not matched"]
                    )
                )
                continue
            }

            let chainRun = await MainActor.run { ChainRunStore.shared.latestRun(for: roomID) }
            let sourceTypes = route.result.sourceRefs.map { $0.sourceType.rawValue }
            let stepStatuses = chainRun?.stepStatusLines ?? []
            let renderSucceeded: Bool
            if let renderStep = chainRun?.steps.first(where: { $0.key == "renderStockMoveCard" }) {
                renderSucceeded = renderStep.status == .succeeded
            } else {
                renderSucceeded = false
            }

            var issues: [String] = []
            if testCase.name.hasPrefix("stock") {
                if route.result.verification.status == "verified" && sourceTypes.filter({ $0 == "quote" }).isEmpty {
                    issues.append("verified without quote source")
                }
                if route.result.verification.status == "verified" &&
                    (sourceTypes.filter({ $0 == "news" || $0 == "disclosure" }).isEmpty ||
                     sourceTypes.filter({ $0 == "marketIndex" }).isEmpty) {
                    issues.append("verified without narrative or market source")
                }
                if renderSucceeded == false && (sourceTypes.contains("quote") || sourceTypes.contains("news") || sourceTypes.contains("disclosure")) {
                    issues.append("stock card did not render")
                }
            }
            if testCase.name == "mail-command-only" || testCase.name == "mail-ambiguous" {
                if route.result.sourceRefs.isEmpty == false {
                    issues.append("mail without confirmed body produced sources")
                }
                if route.result.verification.status == "verified" {
                    issues.append("mail without confirmed body was verified")
                }
            }
            if testCase.name == "mail-body" {
                if route.result.sourceRefs.isEmpty {
                    issues.append("mail body was not recognized")
                }
                if route.result.verification.status == "blocked" {
                    issues.append("mail body should not be blocked")
                }
            }
            if testCase.name == "document-no-text" {
                if let extractStep = chainRun?.steps.first(where: { $0.key == "extractText" }) {
                    if extractStep.status != .failed(failureCode: "ocr_needed") &&
                        extractStep.status != .failed(failureCode: "no_attachment") {
                        issues.append("document without text unexpectedly succeeded")
                    }
                } else {
                    issues.append("document without text unexpectedly succeeded")
                }
            }
            if testCase.name == "document-image-no-ocr" {
                if chainRun?.steps.first(where: { $0.key == "extractText" })?.status != .failed(failureCode: "ocr_needed") {
                    issues.append("image without OCR text unexpectedly succeeded")
                }
            }
            if testCase.name == "document-pdf-with-text" {
                if chainRun?.steps.first(where: { $0.key == "extractText" })?.status != .succeeded {
                    issues.append("text PDF did not reach extractText success")
                }
            }
            if testCase.name.hasPrefix("action-") {
                issues.append("manual action runtime smoke case: verify ActionRuntime directly")
            }

            results.append(
                ChainRuntimeSmokeCaseResult(
                    name: testCase.name,
                    input: testCase.message,
                    chainID: chainRun?.chainID.rawValue ?? route.result.skillID,
                    chainStatus: chainRun?.status.rawValue,
                    verificationStatus: route.result.verification.status,
                    sourceTypes: Array(Set(sourceTypes)).sorted(),
                    stepStatuses: stepStatuses,
                    renderStockMoveCardSucceeded: renderSucceeded,
                    issues: issues
                )
            )
        }
        return results
    }
}
