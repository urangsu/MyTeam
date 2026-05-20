import Foundation

// MARK: - ObservationModels
// Round 243A-OBSERVE: 로컬 관찰 계층 핵심 타입.
//
// 정책:
// - roomID가 nil이면 pendingRoomSelection 상태
// - 파일 내용 원문은 저장하지 않는다
// - fileURL은 sandbox/security-scoped 접근 정책에 맞춰 다룬다
// - 민감 파일명은 summary에 과하게 노출하지 않는다
// - 자동 외부 업로드 금지
// - 자동 파일 수정/삭제 금지

// MARK: - ImplementationLevel (Round 246A: P1-5)
// 각 관찰 컴포넌트가 현재 어느 수준까지 구현되었는지 명시.
// "기능 완료"처럼 보이는 오해 방지.

enum ImplementationLevel {
    case policyOnly        // 정책 선언만, 동작 없음
    case skeleton          // 기초 구조, 핵심 미구현
    case metadataOnly      // 파일명/크기만, 내용 분석 없음
    case explicitReadOnly  // 명시 요청 시 읽기 가능
    case runtimeAvailable  // 실제 완전 동작
}

// MARK: - ObservationSource

enum ObservationSource: String, Codable, CaseIterable, Sendable {
    /// 채팅창 파일 첨부 (드래그 앤 드롭, 클릭 첨부)
    case chatAttachment
    /// 다운로드 폴더 자동 감지 (default off)
    case downloadsFolder
    /// Finder 선택 파일 명시적 읽기
    case finderSelection
    /// 사용자 명시 요청으로만 읽는 클립보드
    case clipboard
    /// 단발성 사용자 명시 요청 화면 스냅샷 (planned)
    case screenSnapshot
    /// 파일 패널/다이얼로그를 통한 수동 임포트
    case manualFileImport

    var displayName: String {
        switch self {
        case .chatAttachment:   return "파일 첨부"
        case .downloadsFolder:  return "다운로드 폴더"
        case .finderSelection:  return "Finder 선택"
        case .clipboard:        return "클립보드"
        case .screenSnapshot:   return "화면 스냅샷"
        case .manualFileImport: return "파일 가져오기"
        }
    }

    /// 사용자 명시 액션이 필요한 source
    var requiresExplicitAction: Bool {
        switch self {
        case .chatAttachment, .manualFileImport: return false
        case .downloadsFolder:                   return false   // metadata 감지만; 분석은 사용자 확인 필요
        case .finderSelection, .clipboard, .screenSnapshot: return true
        }
    }
}

// MARK: - ObservationStatus

enum ObservationStatus: String, Codable, Sendable {
    /// 파일/이벤트 감지됨, 아직 방 미배정
    case detected
    /// 방 선택 대기 중 (roomID == nil)
    case pendingRoomSelection
    /// 사용자가 분석 확인함
    case userConfirmed
    /// 분석 완료, artifact로 변환 가능
    case analyzed
    /// 사용자가 무시함
    case ignored
    /// 정책 차단 (credentialLike, 외부 업로드 요청 등)
    case blocked

    var isTerminal: Bool {
        switch self {
        case .analyzed, .ignored, .blocked: return true
        default: return false
        }
    }
}

// MARK: - ObservationContentKind

enum ObservationContentKind: String, Codable, Sendable, CaseIterable {
    case pdf
    case image
    case spreadsheet   // csv, xlsx
    case text          // .txt, .rtf
    case markdown
    case code          // .swift, .py, .js 등
    case archive       // .zip, .tar
    case word          // .docx
    case presentation  // .pptx
    case unknown

    var displayName: String {
        switch self {
        case .pdf:          return "PDF"
        case .image:        return "이미지"
        case .spreadsheet:  return "스프레드시트"
        case .text:         return "텍스트"
        case .markdown:     return "마크다운"
        case .code:         return "코드"
        case .archive:      return "압축 파일"
        case .word:         return "Word 문서"
        case .presentation: return "프레젠테이션"
        case .unknown:      return "파일"
        }
    }

    var systemImageName: String {
        switch self {
        case .pdf:          return "doc.richtext"
        case .image:        return "photo"
        case .spreadsheet:  return "tablecells"
        case .text:         return "doc.text"
        case .markdown:     return "doc.text"
        case .code:         return "chevron.left.forwardslash.chevron.right"
        case .archive:      return "archivebox"
        case .word:         return "doc.richtext"
        case .presentation: return "rectangle.on.rectangle"
        case .unknown:      return "doc"
        }
    }

    /// 파일 확장자에서 kind 추론
    static func from(fileExtension ext: String) -> ObservationContentKind {
        switch ext.lowercased() {
        case "pdf":                     return .pdf
        case "png", "jpg", "jpeg",
             "heic", "gif", "webp":     return .image
        case "csv", "xlsx", "xls",
             "numbers":                 return .spreadsheet
        case "txt", "rtf":              return .text
        case "md", "markdown":          return .markdown
        case "swift", "py", "js", "ts",
             "java", "kt", "rb",
             "go", "rs", "cpp", "h":   return .code
        case "zip", "tar", "gz",
             "7z", "rar":              return .archive
        case "docx", "doc":            return .word
        case "pptx", "ppt":            return .presentation
        default:                        return .unknown
        }
    }
}

// MARK: - LocalObservation

struct LocalObservation: Identifiable, Codable, Sendable {
    let id: UUID
    /// 연결된 방 ID. nil이면 pendingRoomSelection
    var roomID: UUID?
    let source: ObservationSource
    /// 실제 파일 경로 (security-scoped bookmark로 다룸)
    let fileURL: URL?
    /// 사용자에게 보여줄 파일 이름 (full path 노출 금지)
    let displayName: String
    let detectedAt: Date
    let contentKind: ObservationContentKind
    let fileSizeBytes: Int64?
    var status: ObservationStatus
    /// 이 파일에 적합한 skill ID (예: "office-review.accounting")
    var suggestedSkillID: String?
    /// 사용자에게 보여줄 한 줄 요약 (원문/raw path 금지)
    var userVisibleSummary: String

    init(
        id: UUID = UUID(),
        roomID: UUID? = nil,
        source: ObservationSource,
        fileURL: URL? = nil,
        displayName: String,
        detectedAt: Date = Date(),
        contentKind: ObservationContentKind,
        fileSizeBytes: Int64? = nil,
        status: ObservationStatus = .detected,
        suggestedSkillID: String? = nil,
        userVisibleSummary: String = ""
    ) {
        self.id = id
        self.roomID = roomID
        self.source = source
        self.fileURL = fileURL
        self.displayName = displayName
        self.detectedAt = detectedAt
        self.contentKind = contentKind
        self.fileSizeBytes = fileSizeBytes
        self.status = roomID == nil ? .pendingRoomSelection : status
        self.suggestedSkillID = suggestedSkillID
        self.userVisibleSummary = userVisibleSummary.isEmpty
            ? "\(contentKind.displayName) 파일을 발견했어요."
            : userVisibleSummary
    }

    var isPending: Bool { status == .pendingRoomSelection || status == .detected }

    var fileSizeDisplayString: String? {
        guard let bytes = fileSizeBytes else { return nil }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
