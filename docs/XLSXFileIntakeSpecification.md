# XLSX File Intake Specification

**Round**: 279-FILEINTAKE-EXPANSION Phase 1B  
**Status**: Implementation in progress  
**Created**: 2026-05-25

---

## Overview

XLSX (Excel) file reading infrastructure for MyTeam. Extract table data and convert to markdown tables for analysis.

---

## XLSX Structure

### Format
- XLSX = ZIP archive containing XML files
- Similar to DOCX structure (both use OpenXML)
- Main content in `xl/worksheets/sheet1.xml`, `xl/worksheets/sheet2.xml`, etc.
- Metadata in `xl/workbook.xml`
- Relationships in `xl/_rels/workbook.xml.rels`

### Key Files in Archive
```
workbook.xlsx
├── xl/
│   ├── workbook.xml (metadata, sheet list)
│   ├── worksheets/
│   │   ├── sheet1.xml (first sheet data)
│   │   └── sheet2.xml (second sheet data)
│   ├── sharedStrings.xml (cell text values)
│   └── styles.xml (formatting, cell types)
├── _rels/ (relationships)
└── [Content_Types].xml
```

### Cell References
- XLSX uses shared string pool in `sharedStrings.xml`
- Cell values = references to string IDs (e.g., `<v>42</v>` → sharedStrings[42])
- Some cells contain inline strings or formulas

---

## Extraction Strategy

### Level 1: Basic Table Extraction (Phase 1B Goal)
- Unzip XLSX file
- Parse `xl/worksheets/sheet1.xml` (first sheet only)
- Extract row/cell structure
- Map shared strings
- Output: Markdown table

### Level 2: Multi-Sheet Support (Future)
- Iterate all sheets (sheet1.xml, sheet2.xml, etc.)
- Add sheet names as markdown headers
- Concatenate tables with separators

### Level 3: Advanced Features (Future)
- Preserve formatting (bold, colors, fonts)
- Handle merged cells
- Extract formulas
- Support images embedded in cells

---

## Implementation Plan

### Step 1: XLSXFileExtractor.swift (New)

```swift
struct XLSXWorksheet: Sendable {
    let sheetNumber: Int
    let sheetName: String
    let rows: [[String]]  // 2D array of cell values
}

enum XLSXExtractionError: LocalizedError, Sendable {
    case invalidXLSX
    case noSheetsFound
    case noContentXML
    case invalidXML
    case unsupportedFormat
    case extractionFailed(String)
}

enum XLSXFileExtractor {
    static func extractText(from url: URL) throws -> String
    static func extractMarkdown(from url: URL) throws -> String
    private static func extractWorksheets(from url: URL) throws -> [XLSXWorksheet]
    private static func worksheetToMarkdown(_ sheet: XLSXWorksheet) -> String
    private static func parseSharedStrings(_ data: Data) throws -> [String]
}
```

### Key Components
- **ZIPFoundation** (already used for HWP/DOCX): Unzip XLSX
- **XMLParser**: Parse worksheet XML
- **Shared strings**: Extract text from sharedStrings.xml
- **Markdown table**: Convert rows to markdown format

---

## Extraction Flow

### Text Extraction
```
URL → unzip file
    → find xl/worksheets/sheet1.xml
    → find xl/sharedStrings.xml
    → parse both XMLs
    → Map cell values to shared strings
    → Output: String with cell values
```

### Markdown Table Conversion

**Example:**
```
Input XLSX sheet:
[Name,  Age,  City]
[Alice, 30,   NYC]
[Bob,   25,   LA]

Output Markdown:
| Name | Age | City |
|------|-----|------|
| Alice| 30  | NYC  |
| Bob  | 25  | LA   |
```

### Logic
1. Detect first row (header)
2. Build markdown header row with `| col1 | col2 | ... |`
3. Add separator row `|---|---|...`|
4. Add data rows in same format

---

## Sendable & Concurrency

```swift
struct XLSXWorksheet: Sendable { ... }
enum XLSXExtractionError: Sendable { ... }
```

Background extraction:
```swift
let markdown = try await Task(priority: .userInitiated) {
    try XLSXFileExtractor.extractMarkdown(from: fileURL)
}.value
```

---

## Error Handling

| Error | Message (Korean) |
|-------|-----------------|
| invalidXLSX | "XLSX 파일이 손상되었습니다" |
| noSheetsFound | "워크시트가 없습니다" |
| noContentXML | "콘텐츠를 찾을 수 없습니다" |
| invalidXML | "XLSX 형식이 잘못되었습니다" |
| extractionFailed | "데이터 추출 실패" |

---

## Integration

### FileIntakeService.swift
```swift
case "xlsx": return extractXLSX(request)

private static func extractXLSX(_ request: FileIntakeRequest) -> ... {
    let markdown = try XLSXFileExtractor.extractMarkdown(from: request.fileURL)
    // ... standard flow
}
```

### FileIntakePolicy.swift
```swift
case "xlsx":
    return "Excel 파일이 이제 지원됩니다. 테이블 데이터를 마크다운으로 변환합니다."
```

---

## Testing

### Unit Tests
- ✅ Valid XLSX with single sheet → extracts correctly
- ✅ XLSX with multiple sheets → uses sheet1
- ✅ Empty worksheet → returns appropriate message
- ✅ Corrupted XLSX → throws error
- ✅ Special characters (가나다) → preserves
- ✅ Numbers vs text → both handled

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `MyTeam/XLSXFileExtractor.swift` | CREATE |
| `MyTeam/FileIntakeService.swift` | MODIFY (add xlsx case) |
| `MyTeam/FileIntakePolicy.swift` | MODIFY (xlsx to readable) |
| `scripts/preflight_round279_xlsx_intake.sh` | CREATE |
| `docs/XLSXFileIntakeSpecification.md` | CREATE |

---

## Success Criteria

- [x] Spec created
- [ ] XLSXFileExtractor implemented
- [ ] FileIntakeService integrated
- [ ] FileIntakePolicy updated
- [ ] Preflight 12/12 PASS
- [ ] Build: 0 warnings

---

## Known Limitations

- Multi-sheet: Only sheet1 processed (will handle in Phase 2)
- Complex layouts: Treated as flat table
- Formulas: Cell computed values only (not formula text)
- Formatting: Not preserved (plain text)
- Images: Ignored
- Merged cells: May produce empty cells

---

## Comparison with HWP/PDF

| Feature | HWP | PDF | XLSX |
|---------|-----|-----|------|
| Parser | Custom XML | PDFKit | ZIPFoundation + XML |
| Structure | Paragraphs | Pages | Tables |
| Output | Markdown | Markdown | Markdown tables |
| Complexity | Medium | High | Low |
