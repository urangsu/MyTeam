# HWP 파일 포맷 명세서 및 추출 전략

**Date**: 2026-05-25  
**Round**: 277-KOREAN-HWP-INTAKE  
**Status**: Foundation + Skeleton Implementation

---

## 1. HWP/HWPX 파일 구조

### 개요
- **형식**: ZIP 기반 패키지 (한글과컴퓨터 표준)
- **확장자**: 
  - `.hwp` — HWP 2.0 (한글 97 이상)
  - `.hwpx` — HWP 5.0+ (압축 형식, .hwp와 동일한 구조)
- **내부 구조**:
  ```
  .hwp (또는 .hwpx)
  ├── [Content_Types].xml      — 미디어 타입 정의
  ├── _rels/                   — 관계 정보
  ├── docProps/                — 문서 메타데이터
  ├── content.xml              — 본문 내용 (텍스트 주요 부분)
  ├── styles.xml               — 스타일 정의
  ├── numbering.xml            — 번호/글머리 정의
  ├── document.xml             — 추가 내용 (선택)
  └── media/                   — 이미지, 객체 (선택)
  ```

### content.xml 구조 (마크다운 추출 대상)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<p:documentPart xmlns:p="...">
  <p:body>
    <p:section>
      <p:paragraph>
        <p:pPr>
          <p:pStyle val="Heading1" />  <!-- 제목 스타일 -->
        </p:pPr>
        <p:text>텍스트 내용</p:text>
      </p:paragraph>
      
      <p:paragraph>
        <p:text>본문 내용</p:text>
      </p:paragraph>
      
      <p:list>  <!-- 목록 -->
        <p:listItem><p:text>항목 1</p:text></p:listItem>
        <p:listItem><p:text>항목 2</p:text></p:listItem>
      </p:list>
    </p:section>
  </p:body>
</p:documentPart>
```

---

## 2. 추출 전략 (1차 구현)

### 레벨 1: 텍스트만 추출 (이번 구현)
- XML 파싱으로 텍스트 노드만 추출
- 스타일 정보 무시 (굵기, 색상, 글꼴)
- 마크다운 변환:
  - Heading 스타일 → `## 제목`
  - 본문 → 단락 (개행)
  - 목록 → `- 항목`

### 레벨 2: 서식 추출 (향후)
- 굵기, 이탤릭, 밑줄 정보 보존
- 표(table) 지원
- 이미지/객체 참조

### 레벨 3: 완전 재구성 (향후)
- 다단계 구조 보존
- 수식 처리
- 변경 이력 추출

---

## 3. 구현 계획

### 3.1 HWPFileExtractor.swift
```swift
enum HWPFileExtractor {
    /// HWP 파일에서 텍스트 추출
    static func extractText(from url: URL) throws -> String
    
    /// HWP 파일에서 마크다운 추출
    static func extractMarkdown(from url: URL) throws -> String
    
    /// 내부: content.xml 파싱
    private static func parseContentXML(data: Data) -> [HWPParagraph]
    
    /// 내부: ZIP 언팩
    private static func unpackArchive(at url: URL) throws -> [String: Data]
}

struct HWPParagraph {
    let style: String?  // "Heading1", "Normal", etc.
    let text: String
    let isListItem: Bool
}
```

### 3.2 FileIntakeService 확장
```swift
case "hwp", "hwpx":
    return ingestHWP(request)

private static func ingestHWP(_ request: FileIntakeRequest) -> DocumentIngestionResult {
    do {
        let markdown = try HWPFileExtractor.extractMarkdown(from: request.fileURL)
        let warnings: [DocumentIngestionWarning] = []
        
        return DocumentIngestionResult(
            status: .ready,
            format: .hwp,
            normalizedText: markdown,
            warnings: warnings,
            metadataSummary: "한글 문서 추출 완료",
            userMessage: "HWP 파일을 마크다운으로 변환했습니다."
        )
    } catch {
        return DocumentIngestionResult(
            status: .readFailed,
            format: nil,
            normalizedText: nil,
            warnings: [],
            metadataSummary: nil,
            userMessage: "HWP 파일을 읽을 수 없습니다: \(error.localizedDescription)"
        )
    }
}
```

### 3.3 FileIntakePolicy 업데이트
```swift
static func decision(for request: FileIntakeRequest) -> FileIntakeDecision {
    let ext = request.fileExtension.lowercased()
    
    // HWP/HWPX 지원 추가
    if ext == "hwp" || ext == "hwpx" {
        if request.fileSizeBytes > maxFileSizeBytes {
            return .init(status: .tooLarge, message: "파일이 너무 큽니다.")
        }
        return .init(status: .allowed, message: "HWP 파일을 읽을 수 있습니다.")
    }
    
    // 기존 로직...
}
```

---

## 4. 테스트 케이스

### 4.1 단순 HWP 파일 (테스트용)
```
제목 1
  
본문 첫 번째 단락.
본문 두 번째 단락.

- 항목 1
- 항목 2
- 항목 3

제목 2

추가 본문.
```

### 4.2 복잡한 HWP 파일 (향후)
- 다단계 제목
- 표
- 이미지
- 수식

---

## 5. 의존성 및 제약사항

### 외부 의존성
- **Foundation**: Data, URLResourceValues
- **ZIPFoundation**: ZIP 언팩 (이미 FileIntakeService에서 사용)
- **XMLParser**: XML 파싱 (Swift stdlib)

### 제약사항 (1차 구현)
- 이미지/객체 무시
- 표 미지원 (평탄 텍스트로 변환)
- 헤더/푸터 무시
- 스타일 정보 무시

### 인코딩
- UTF-8 가정 (HWP 내부 인코딩)
- 한글 텍스트 손상 위험 최소화

---

## 6. 에러 처리

```swift
enum HWPExtractionError: LocalizedError {
    case invalidZipArchive
    case missingContentXML
    case invalidXMLFormat
    case encodingError
    case unsupportedHWPVersion
    
    var errorDescription: String? {
        switch self {
        case .invalidZipArchive:
            return "HWP 파일이 손상되었거나 ZIP 형식이 아닙니다."
        case .missingContentXML:
            return "HWP 파일에서 content.xml을 찾을 수 없습니다."
        case .invalidXMLFormat:
            return "HWP 파일의 XML 형식이 잘못되었습니다."
        case .encodingError:
            return "파일 인코딩을 처리할 수 없습니다."
        case .unsupportedHWPVersion:
            return "지원하지 않는 HWP 버전입니다."
        }
    }
}
```

---

## 7. 향후 확장 계획

### Phase 1B (다음)
- 고유명사 정규화로 한글 텍스트 품질 향상
- "홍길동", "삼성전자" 등 감지 및 TTS 최적화

### Phase 2 (향후)
- 표(table) 추출 및 마크다운 테이블 변환
- 이미지 참조 정보 보존

### Phase 3 (향후)
- Word 호환 변환 (DOCX → HWP)
- 양방향 변환 가능성 연구

---

## 참고 자료

- **HWP 파일 포맷**: 한글과컴퓨터 공식 명세 (OpenFormat)
- **유사 구현**: DOCX/PPTX Intake (FileIntakeService.swift 참고)
- **XML 파싱**: Swift XMLParser 공식 문서

