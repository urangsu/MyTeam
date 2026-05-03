import Foundation

// MARK: - DeckPlan
// create_presentation_plan 출력(pptx-plan-v1)과 호환

struct DeckPlan: Codable {
    let format: String      // "pptx-plan-v1"
    let title: String
    let slideCount: Int
    let slides: [SlidePlan]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format    = (try? c.decode(String.self,      forKey: .format))     ?? "pptx-plan-v1"
        title     = try  c.decode(String.self,        forKey: .title)
        slides    = (try? c.decode([SlidePlan].self,  forKey: .slides))    ?? []
        slideCount = (try? c.decode(Int.self,         forKey: .slideCount)) ?? slides.count
    }
}

struct SlidePlan: Codable {
    let title:    String
    let subtitle: String?
    let content:  String?
    let bullets:  [String]?
    let notes:    String?
    let layout:   SlideLayout?

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        title    = (try? c.decode(String.self,       forKey: .title))    ?? ""
        subtitle = try? c.decode(String.self,         forKey: .subtitle)
        content  = try? c.decode(String.self,         forKey: .content)
        bullets  = try? c.decode([String].self,       forKey: .bullets)
        notes    = try? c.decode(String.self,         forKey: .notes)
        layout   = try? c.decode(SlideLayout.self,   forKey: .layout)
    }
}

enum SlideLayout: String, Codable {
    case title            // 표지
    case titleAndBullets  // 제목 + 글머리
    case section          // 섹션 구분
    case quote            // 인용
    case closing          // 마지막 슬라이드
}

// MARK: - WorkbookPlan
// create_spreadsheet_plan 출력(xlsx-plan-v1)과 호환

struct WorkbookPlan: Codable {
    let format: String      // "xlsx-plan-v1"
    let title:  String
    let sheets: [SheetPlan]

    private enum CodingKeys: String, CodingKey { case format, title, sheets, data }

    init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        format = (try? c.decode(String.self,    forKey: .format)) ?? "xlsx-plan-v1"
        title  = try  c.decode(String.self,      forKey: .title)

        if let multi = try? c.decode([SheetPlan].self, forKey: .sheets) {
            sheets = multi
        } else if let raw = try? c.decode(RawSheetData.self, forKey: .data) {
            // CreateSpreadsheetPlanTool 단일 시트 포맷 정규화
            sheets = [SheetPlan(name: title, headers: raw.headers,
                                rows: raw.stringRows, summary: nil)]
        } else {
            sheets = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(title,  forKey: .title)
        try c.encode(sheets, forKey: .sheets)
    }

    init(format: String, title: String, sheets: [SheetPlan]) {
        self.format = format; self.title = title; self.sheets = sheets
    }
}

struct SheetPlan: Codable {
    let name:    String
    let headers: [String]
    let rows:    [[String]]
    let summary: String?
}

// MARK: - Private helper: mixed-type JSON row decoder

private struct RawSheetData: Decodable {
    let headers: [String]
    private let rows: [[JSONAny]]
    var stringRows: [[String]] { rows.map { $0.map { $0.stringValue } } }
}

private enum JSONAny: Decodable {
    case string(String), number(Double), bool(Bool), null

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .bool(let b):   return b ? "true" : "false"
        case .null:          return ""
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self)  { self = .string(s); return }
        if let n = try? c.decode(Double.self)  { self = .number(n); return }
        if let b = try? c.decode(Bool.self)    { self = .bool(b);   return }
        self = .null
    }
}

// MARK: - DocumentGenerationResult

struct DocumentGenerationResult {
    let url:          URL
    let title:        String
    let format:       DocumentOutputFormat
    let pageCount:    Int            // 슬라이드 수 / 데이터 행 수
    let artifactPath: String         // workspace 상대 경로 (파일명)
}

enum DocumentOutputFormat: String {
    case pptx, xlsx
}

// MARK: - Cloud stubs (Phase B)

struct CloudDocumentResult {
    let id:       String
    let url:      URL
    let title:    String
    let provider: CloudProvider
}

enum CloudProvider: String, Codable {
    case googleSlides, googleSheets
}
