# DOCX File Intake Specification

**Phase:** Round 279-FILEINTAKE-EXPANSION Phase 1C  
**Status:** Implementation Complete  
**Last Updated:** 2026-05-25

---

## 1. Overview

The `DOCXFileExtractor` module extracts structured text content from Microsoft Word (.docx) files, converting them to markdown format for document ingestion. DOCX is a ZIP-based format containing XML documents; we parse `word/document.xml` to extract paragraphs and detect heading styles.

**Key Design Decisions:**
- Single-pass XMLParser with delegate pattern (memory-efficient for large documents)
- Heading detection via `w:pStyle` attributes (val contains "Heading" → isHeading = true)
- Paragraph-granular extraction (respects document structure)
- No image/embedded object extraction (text-only scope)
- Error handling: 4 LocalizedError cases with Korean user messages

---

## 2. DOCX File Structure

```
document.docx (ZIP archive)
├── [Content_Types].xml
├── _rels/.rels
├── word/
│   ├── document.xml       ← Main content (parsed)
│   ├── styles.xml         (not parsed, style names extracted from pStyle val)
│   ├── document.xml.rels
│   ├── media/             (images, ignored)
│   └── embeddings/        (ignored)
├── word/_rels/
└── docProps/              (metadata, ignored)
```

**Parsing Target:** `word/document.xml`

---

## 3. Paragraph and Heading Detection

### XML Structure (Simplified)
```xml
<w:document>
  <w:body>
    <!-- Regular paragraph -->
    <w:p>
      <w:pPr />
      <w:r>
        <w:t>Text content</w:t>
      </w:r>
    </w:p>
    
    <!-- Heading paragraph -->
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1" />
      </w:pPr>
      <w:r>
        <w:t>Title</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>
```

### Heading Detection Logic
- When `<w:pStyle>` element encountered with attribute `w:val` containing "heading" (case-insensitive) → set `isHeading = true` for current paragraph
- Standard heading styles: `Heading1`, `Heading2`, `HeadingChar`, etc.
- Non-heading paragraphs: `Normal`, `List Bullet`, custom styles not containing "heading"

### DOCXParagraph Structure
```swift
struct DOCXParagraph: Sendable {
    let text: String           // Concatenated text from all runs in paragraph
    let isHeading: Bool        // true if pStyle.val contains "heading"
}
```

---

## 4. Extraction Flow

### 1. **Archive Access**
- Open DOCX as ZIP using `ZIPFoundation.Archive`
- Access `word/document.xml` entry
- Extract data via `archive.extract(entry, consumer: { chunk in data.append(chunk) })`

### 2. **XML Parsing**
- Create `XMLParser` with extracted data
- Attach delegate conforming to `XMLParserDelegate`
- Call `parser.parse()` to trigger delegate callbacks

### 3. **Delegate State Machine**
| Event | Handler | State Change |
|-------|---------|--------------|
| `didStartElement p` | Set `inParagraph=true`, reset `currentText=""` | Paragraph boundary |
| `didStartElement t` (inside p) | Set `inRunText=true` | Text run boundary |
| `didStartElement pStyle` | Check `w:val` attribute → set `isHeading` | Style detection |
| `foundCharacters` | Append to `currentText` if `inRunText` | Text accumulation |
| `didEndElement t` | Set `inRunText=false` | End text run |
| `didEndElement p` | Create `DOCXParagraph(text, isHeading)`, append to array | Finalize paragraph |

### 4. **Markdown Conversion**
```swift
paragraphs.map { para in
    if para.isHeading {
        return "## \(para.text)"       // Heading → ## level 2
    } else {
        return para.text               // Body → plain text
    }
}
.filter { !$0.isEmpty }
.joined(separator: "\n\n")             // Separate paragraphs with blank lines
```

---

## 5. Error Handling

### DOCXExtractionError (4 cases)

| Case | Trigger | User Message (Korean) | Recovery Suggestion |
|------|---------|----------------------|-------------------|
| `.invalidDOCX` | `Archive(url:)` returns nil | "DOCX 파일이 손상되었습니다" | Retry with different file |
| `.noContent` | `word/document.xml` missing or no paragraphs extracted | "이 DOCX 파일에는 콘텐츠가 없습니다" | Try another Word file |
| `.invalidXML` | `parser.parse()` returns false | "DOCX 형식이 잘못되었습니다" | Re-save file in Word, retry |
| `.extractionFailed(String)` | Unexpected parsing error (future use) | "콘텐츠 추출 실패: \(detail)" | (varies by detail) |

All conform to `LocalizedError` + `Sendable` for Swift concurrency.

---

## 6. Public API

### extractText(from:) → String
Extracts plain text (no markdown formatting).
```swift
let text = try DOCXFileExtractor.extractText(from: docxURL)
// Returns: "Title\nSome paragraph text\n..."
```

### extractMarkdown(from:) → String
Extracts markdown with heading-level formatting.
```swift
let markdown = try DOCXFileExtractor.extractMarkdown(from: docxURL)
// Returns: "## Title\n\nSome paragraph text\n..."
```

---

## 7. Integration with FileIntakeService

**Routing (FileIntakeService.swift:81-82):**
```swift
} else if ext == "docx" {
    extracted = try DOCXFileExtractor.extractMarkdown(from: request.fileURL)
```

**Error Handling (FileIntakeService.swift:131-137):**
```swift
} catch let error as DOCXExtractionError {
    return FileIntakeResult(
        status: .readFailed,
        request: request,
        extractedText: nil,
        userMessage: "Word 파일을 읽을 수 없습니다: \(error.localizedDescription ?? "Unknown error")"
    )
```

**FileIntakePolicy Extension (FileIntakePolicy.swift:19):**
- Moved `"docx"` from `plannedExtensions` → `readableExtensions`
- Status: `.allowed` (users can now upload .docx files)

---

## 8. Limitations & Future Work

### Current Scope (Phase 1C)
- ✅ Text extraction from regular paragraphs
- ✅ Heading detection via style names
- ✅ Markdown conversion (paragraphs + headings)
- ✅ Error handling + localization
- ✅ Swift concurrency (Sendable)

### Out of Scope (Phase 1C+)
- ❌ Tables (complex XML nesting, requires cell boundary detection)
- ❌ Images + captions
- ❌ Hyperlinks + footnotes (text-only for now)
- ❌ Tracked changes / Comments
- ❌ Formatting preservation (bold, italic, font colors)
- ❌ Multi-level heading hierarchy (all headings → ## level 2)

### Known Behaviors
- Multiple consecutive blank paragraphs → collapse to single `\n\n`
- Whitespace-only paragraphs → filtered out
- Text runs within a paragraph → concatenated with no separator
- Character encoding → handled by XMLParser (UTF-8 expected per .docx spec)

---

## 9. Testing Checklist

When verifying Phase 1C implementation:

1. ✅ `DOCXFileExtractor.swift` exists in `MyTeam/`
2. ✅ `extractText()` and `extractMarkdown()` public functions
3. ✅ `DOCXParagraph` struct with `Sendable` conformance
4. ✅ `DOCXExtractionError` enum with `LocalizedError` + `Sendable`
5. ✅ `XMLParserDelegate` implementation in `parseDocument()`
6. ✅ `FileIntakeService.swift` routes `ext == "docx"` to `DOCXFileExtractor.extractMarkdown()`
7. ✅ `FileIntakePolicy.swift` includes `"docx"` in `readableExtensions`
8. ✅ Error catch block in `FileIntakeService.readText()` handles `DOCXExtractionError`
9. ✅ Preflight script `scripts/preflight_round279_docx_intake.sh` passes all checks
10. ✅ No compiler warnings or errors in Debug/Release builds

---

## 10. References

- [OOXML Standard (ISO/IEC 29500)](https://en.wikipedia.org/wiki/Office_Open_XML)
- [ZIPFoundation GitHub](https://github.com/weichsel/ZIPFoundation)
- [XMLParser (NSXMLParser) Documentation](https://developer.apple.com/documentation/foundation/xmlparser)
- Related: `PDFFileIntakeSpecification.md`, `XLSXFileIntakeSpecification.md`
