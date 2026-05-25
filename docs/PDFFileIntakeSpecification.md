# PDF File Intake Specification

**Round**: 279-FILEINTAKE-EXPANSION Phase 1A  
**Status**: Implementation in progress  
**Created**: 2026-05-25

---

## Overview

PDF file reading infrastructure for MyTeam. Extract text content and convert to markdown for further analysis.

---

## PDF Structure

### Format
- PDF 1.4+ (industry standard)
- Text vs. Scanned PDFs supported
- Binary format with embedded text streams

### Extraction Strategy

#### Level 1: Basic Text Extraction
- Identify PDF text streams (Content streams)
- Decode `/FlateDecode` compression
- Extract raw text without formatting
- Output: Plain text

#### Level 2: Structure-Aware Extraction (Phase 1A Goal)
- Identify text blocks and positioning
- Detect paragraphs (Y-position gaps)
- Detect headings (font size changes)
- Convert to markdown with headers, lists
- Output: Markdown

#### Level 3: Advanced Layout (Future)
- Table detection (grid patterns)
- Column detection (multi-column layouts)
- Image/graphic reference preservation
- Form field handling

---

## Implementation Plan

### Step 1: PDFKitExtractor.swift (New)

```swift
struct PDFPage: Sendable {
    let pageNumber: Int
    let text: String
    let height: CGFloat
    let width: CGFloat
}

enum PDFExtractionError: LocalizedError, Sendable {
    case invalidPDF
    case noTextFound
    case encryptedPDF
    case unsupportedVersion
    case extractionFailed(String)
}

enum PDFFileExtractor {
    static func extractText(from url: URL) throws -> String
    static func extractMarkdown(from url: URL) throws -> String
    private static func extractPages(from url: URL) throws -> [PDFPage]
    private static func pageToMarkdown(_ page: PDFPage) -> String
}
```

### Key Components
- **PDFDocument** (PDFKit): Load and parse PDF
- **PDFPage iteration**: Extract each page
- **Text extraction**: PDFPage.string or manual stream parsing
- **Markdown conversion**: Simple heuristics (empty lines = paragraphs, etc.)

### Libraries
- **PDFKit** (Apple framework): Built-in, no SPM dependency
- Already linked in MyTeam target

---

## Extraction Logic

### Text Extraction Flow
```
URL → PDFDocument.init(url:)
    → Check encrypted: PDFDocument.isEncrypted
    → Iterate PDFDocument.pageCount
    → For each: PDFPage.string (text content)
    → Decode UTF-8
    → Normalize whitespace
    → Output: String
```

### Markdown Conversion Heuristics

**Simple Rules:**
1. Multiple newlines (≥2) → paragraph break
2. Text at Y < 50 from top → potential heading
3. Indented lines → list items
4. All-caps lines → section headers
5. URLs detected → markdown links
6. Tab indentation → nested lists

**Example:**
```
Input PDF text:
"Introduction\n\nThis is the first paragraph.\nIt continues here.\n\nNext section\n\nSecond paragraph."

Output Markdown:
"# Introduction\n\nThis is the first paragraph. It continues here.\n\n# Next section\n\nSecond paragraph."
```

---

## Sendable & Concurrency

All structures conform to `Sendable`:
```swift
struct PDFPage: Sendable { ... }
enum PDFExtractionError: Sendable { ... }
```

Extraction runs on background thread:
```swift
let text = try await Task(priority: .userInitiated) {
    try PDFFileExtractor.extractMarkdown(from: fileURL)
}.value
```

---

## Error Handling

| Error | Message (Korean) | User-Facing |
|-------|-----------------|-------------|
| invalidPDF | "PDF 파일이 손상되었습니다" | "파일을 열 수 없습니다" |
| noTextFound | "텍스트 내용이 없습니다" | "이 PDF는 스캔된 이미지입니다" |
| encryptedPDF | "암호화된 PDF입니다" | "암호화된 파일을 열 수 없습니다" |
| extractionFailed | "텍스트 추출 실패" | "내용을 읽을 수 없습니다" |

---

## Integration Points

### FileIntakeService.swift
```swift
case "pdf": return ingestPDF(request)

private static func ingestPDF(_ request: FileIntakeRequest) -> DocumentIngestionResult {
    do {
        let markdown = try PDFFileExtractor.extractMarkdown(from: request.fileURL)
        guard !markdown.isEmpty else {
            return DocumentIngestionResult(
                status: .empty,
                format: .pdf,
                normalizedText: nil,
                warnings: [.noContent],
                metadataSummary: "pdf empty",
                userMessage: "PDF에서 텍스트를 찾지 못했습니다. 스캔된 이미지일 수 있습니다."
            )
        }
        // ... standard ingestion flow
    } catch {
        return DocumentIngestionResult(
            status: .readFailed,
            format: .pdf,
            normalizedText: nil,
            warnings: [],
            metadataSummary: "pdf readFailed",
            userMessage: "PDF를 열 수 없습니다: \(error.localizedDescription)"
        )
    }
}
```

### FileIntakePolicy.swift
```swift
static let readableExtensions: Set<String> = [
    "txt", "md", "markdown", "csv", "pdf", "xlsx", "docx", "pptx", "hwp", "hwpx"
]
```

Update `extToPlannedMessage(_:)`:
```swift
case "pdf":
    return "PDF 읽기가 이제 지원됩니다. 파일을 드래그해서 텍스트를 추출하세요."
```

---

## DocumentIngestionResult Extension

Add `.pdf` case:
```swift
enum DocumentFormat: String, Codable {
    case txt, md, csv, pdf, xlsx, docx, pptx, hwp, hwpx
}
```

---

## Testing

### Unit Tests
- ✅ Valid PDF with text → extracts correctly
- ✅ Empty PDF → returns noContent warning
- ✅ Encrypted PDF → throws encryptedPDF error
- ✅ Corrupted PDF → throws invalidPDF error
- ✅ Multi-page PDF → combines all pages
- ✅ PDF with special chars (가나다, etc.) → preserves correctly

### Preflight Checks (scripts/preflight_round279_pdf_intake.sh)
1. PDFFileExtractor.swift exists
2. extractText() function present
3. extractMarkdown() function present
4. PDFExtractionError enum present
5. FileIntakeService.ingestPDF() present
6. FileIntakePolicy.pdf case present
7. DocumentFormat.pdf case present
8. Error handling present (LocalizedError)
9. Sendable conformance present
10. PDFKit import present
11. All 10 checks pass

---

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `MyTeam/PDFFileExtractor.swift` | CREATE | PDF extraction logic |
| `MyTeam/FileIntakeService.swift` | MODIFY | Add ingestPDF() |
| `MyTeam/FileIntakePolicy.swift` | MODIFY | Add pdf to readableExtensions + message |
| `MyTeam/ChatModels.swift` | MODIFY | Add .pdf to DocumentFormat enum |
| `scripts/preflight_round279_pdf_intake.sh` | CREATE | 10-check verification |
| `docs/PDFFileIntakeSpecification.md` | CREATE | This file |

---

## Success Criteria

- [x] Spec document created
- [ ] PDFFileExtractor.swift implemented
- [ ] FileIntakeService integration complete
- [ ] FileIntakePolicy updated
- [ ] DocumentFormat extended
- [ ] Error handling tested
- [ ] Preflight 10/10 PASS
- [ ] Build: 0 warnings

---

## Known Limitations

- Scanned PDFs (image-based) will show "noContent" → user guided to OCR tool
- Complex layouts (multi-column, tables) treated as plain text
- Embedded images ignored
- Form fields not processed
- Encrypted PDFs rejected (requires password)

---

## Next Phase

Phase 1B: XLSX file intake (similar structure, ZIP-based)
