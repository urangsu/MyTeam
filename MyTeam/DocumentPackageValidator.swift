import Foundation

// MARK: - DocumentPackageValidator
//
// 생성된 PPTX / XLSX 파일이 최소 필수 OOXML part를 포함하고
// 내부 참조(rels)가 일관성이 있는지 검증한다.
//
// ── 전제 조건 (MiniZipWriter 계약) ──
// MiniZipWriter는 stored method (compMethod = 0)만 사용한다.
// OOXML 스펙상 stored ZIP은 완전히 유효하며, PowerPoint/Excel/Keynote/Numbers 모두 읽는다.
// Validator는 이 계약에 의존해 XML 내용을 압축 해제 없이 직접 읽는다.
//
// 만약 향후 deflate(method=8) 지원이 추가되면:
//   → zipContents()에서 방법 8 항목은 .compressedContent 에러를 throw한다.
//   → 호출측에서 deflate 지원을 구현하거나, 해당 파일만 skip하도록 정책 결정이 필요하다.
//
// ── 검증 정책 ──
// 필수 part 존재 확인 → 필수 XML 내용 읽기 성공 → content/rels 검사
// 조용한 skip 없음. 내용을 읽을 수 없으면 validation failure.

enum DocumentPackageValidator {

    // MARK: - 필수 XML 목록 (내용까지 반드시 읽혀야 하는 파일)

    private static let pptxRequiredContent: Set<String> = [
        "[Content_Types].xml",
        "ppt/_rels/presentation.xml.rels"
    ]
    private static let xlsxRequiredContent: Set<String> = [
        "[Content_Types].xml",
        "xl/_rels/workbook.xml.rels",
        "xl/sharedStrings.xml"
    ]

    // MARK: - PPTX 검증

    /// PPTX 최소 필수 part 검증.
    /// - Parameters:
    ///   - url: .pptx 파일 경로
    ///   - expectedSlideCount: DeckPlan.slides.count
    static func validatePPTX(at url: URL, expectedSlideCount: Int) throws {
        let (entries, contents) = try zipContents(at: url)

        // 1) 필수 part 존재 확인
        let requiredParts: [String] = [
            "[Content_Types].xml",
            "ppt/presentation.xml",
            "ppt/_rels/presentation.xml.rels",
            "ppt/slides/slide1.xml"
        ]
        for part in requiredParts {
            guard entries.contains(part) else {
                throw DocumentValidationError.missingPart(part)
            }
        }

        // 2) 필수 XML 내용 읽기 성공 여부 확인 (silent skip 금지)
        for part in pptxRequiredContent {
            guard contents[part] != nil else {
                throw DocumentValidationError.unreadableContent(part)
            }
        }

        // 3) [Content_Types].xml에 slide content type이 있는지
        let ctXML = contents["[Content_Types].xml"]!
        guard ctXML.contains("application/vnd.openxmlformats-officedocument.presentationml.slide") else {
            throw DocumentValidationError.contentTypeMissing("presentationml.slide")
        }

        // 4) presentation.xml.rels에 slide 관계가 있는지
        let relsXML = contents["ppt/_rels/presentation.xml.rels"]!
        guard relsXML.contains("slide") else {
            throw DocumentValidationError.missingRelationship("slide", in: "presentation.xml.rels")
        }

        // 5) slide 파일 개수 확인
        let slideFiles = entries.filter {
            $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") && !$0.contains("_rels")
        }
        guard slideFiles.count == expectedSlideCount else {
            throw DocumentValidationError.slideCountMismatch(expected: expectedSlideCount, actual: slideFiles.count)
        }

        AppLog.info("[Validator] PPTX OK: \(slideFiles.count)장, \(entries.count) parts")
    }

    // MARK: - XLSX 검증

    /// XLSX 최소 필수 part 검증.
    /// - Parameters:
    ///   - url: .xlsx 파일 경로
    ///   - expectedSheetCount: WorkbookPlan.sheets.count
    static func validateXLSX(at url: URL, expectedSheetCount: Int) throws {
        let (entries, contents) = try zipContents(at: url)

        // 1) 필수 part 존재 확인
        let requiredParts: [String] = [
            "[Content_Types].xml",
            "xl/workbook.xml",
            "xl/_rels/workbook.xml.rels",
            "xl/worksheets/sheet1.xml",
            "xl/sharedStrings.xml",
            "xl/styles.xml"
        ]
        for part in requiredParts {
            guard entries.contains(part) else {
                throw DocumentValidationError.missingPart(part)
            }
        }

        // 2) 필수 XML 내용 읽기 성공 여부 확인 (silent skip 금지)
        for part in xlsxRequiredContent {
            guard contents[part] != nil else {
                throw DocumentValidationError.unreadableContent(part)
            }
        }

        // 3) workbook.xml.rels가 sheet를 참조하는지
        let relsXML = contents["xl/_rels/workbook.xml.rels"]!
        guard relsXML.contains("worksheets/sheet") else {
            throw DocumentValidationError.missingRelationship("worksheet", in: "workbook.xml.rels")
        }

        // 4) 시트 파일 개수 확인
        let sheetFiles = entries.filter {
            $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml")
        }
        guard sheetFiles.count == expectedSheetCount else {
            throw DocumentValidationError.sheetCountMismatch(expected: expectedSheetCount, actual: sheetFiles.count)
        }

        // 5) sharedStrings.xml declared count vs 실제 si 개수 불일치 경고
        let ssXML = contents["xl/sharedStrings.xml"]!
        let actualSI = ssXML.components(separatedBy: "<si>").count - 1
        if let declared = parseXMLAttribute(ssXML, name: "uniqueCount") ?? parseXMLAttribute(ssXML, name: "count"),
           declared > 0, actualSI < declared / 2 {
            AppLog.warning("[Validator] sharedStrings count 불일치 (declared: \(declared), actual si: \(actualSI)) — 계속 진행")
        }

        AppLog.info("[Validator] XLSX OK: \(sheetFiles.count)시트, \(entries.count) parts")
    }

    // MARK: - ZIP Central Directory 파싱

    /// ZIP 파일에서 파일명 목록과 UTF-8 텍스트 파일 내용을 추출.
    ///
    /// ⚠️ stored method(0)만 내용을 읽는다. deflate(8) 항목은 `.compressedContent` 에러를 throw한다.
    /// MiniZipWriter는 stored만 사용하므로 정상 경로에서는 에러가 발생하지 않는다.
    private static func zipContents(at url: URL) throws -> (entries: Set<String>, contents: [String: String]) {
        let data = try Data(contentsOf: url)
        guard data.count > 22 else { throw DocumentValidationError.corruptedFile }

        let bytes = [UInt8](data)

        // EOCD 시그니처: 0x06054b50 (LE)
        let eocdSig: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        guard let eocdOffset = findSignature(eocdSig, in: bytes, searchFromEnd: true) else {
            throw DocumentValidationError.corruptedFile
        }

        let cdOffset   = Int(readU32(bytes, at: eocdOffset + 16))
        let entryCount = Int(readU16(bytes, at: eocdOffset + 12))

        var entries: Set<String> = []
        var contents: [String: String] = [:]
        var pos = cdOffset
        let cdSig:    [UInt8] = [0x50, 0x4b, 0x01, 0x02]
        let localSig: [UInt8] = [0x50, 0x4b, 0x03, 0x04]

        for _ in 0..<entryCount {
            guard pos + 46 <= bytes.count else { break }
            guard bytes[pos..<pos+4].elementsEqual(cdSig) else { break }

            let compMethod  = Int(readU16(bytes, at: pos + 10))
            let compSize    = Int(readU32(bytes, at: pos + 20))
            let nameLen     = Int(readU16(bytes, at: pos + 28))
            let extraLen    = Int(readU16(bytes, at: pos + 30))
            let commentLen  = Int(readU16(bytes, at: pos + 32))
            let localOffset = Int(readU32(bytes, at: pos + 42))

            let nameStart = pos + 46
            let nameEnd   = nameStart + nameLen
            guard nameEnd <= bytes.count else { break }

            if let name = String(bytes: bytes[nameStart..<nameEnd], encoding: .utf8) {
                entries.insert(name)

                if name.hasSuffix(".xml") {
                    if compMethod == 0 {
                        // stored — 직접 읽기
                        guard localOffset + 30 <= bytes.count,
                              bytes[localOffset..<localOffset+4].elementsEqual(localSig) else {
                            pos = nameEnd + extraLen + commentLen
                            continue
                        }
                        let localNameLen  = Int(readU16(bytes, at: localOffset + 26))
                        let localExtraLen = Int(readU16(bytes, at: localOffset + 28))
                        let dataStart = localOffset + 30 + localNameLen + localExtraLen
                        let dataEnd   = dataStart + compSize
                        if dataEnd <= bytes.count,
                           let text = String(bytes: bytes[dataStart..<dataEnd], encoding: .utf8) {
                            contents[name] = text
                        }
                        // 내용 읽기 실패 시 contents에 추가 안 됨 → unreadableContent 에러로 처리됨
                    } else if compMethod == 8 {
                        // deflate — MiniZipWriter는 절대 생성하지 않음.
                        // 외부에서 가져온 파일이거나 writer 계약 위반.
                        throw DocumentValidationError.compressedContent(name)
                    }
                    // 그 외 압축 방법은 무시 (XML 아닌 바이너리 첨부 등)
                }
            }
            pos = nameEnd + extraLen + commentLen
        }
        return (entries, contents)
    }

    // MARK: - XML attribute 파싱

    private static func parseXMLAttribute(_ xml: String, name: String) -> Int? {
        let pattern = "\(name)=\""
        guard let r = xml.range(of: pattern) else { return nil }
        let after = xml[r.upperBound...]
        guard let end = after.firstIndex(of: "\"") else { return nil }
        return Int(after[after.startIndex..<end])
    }

    // MARK: - Binary helpers

    private static func readU16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readU32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
    }

    private static func findSignature(_ sig: [UInt8], in bytes: [UInt8], searchFromEnd: Bool) -> Int? {
        let sigLen = sig.count
        let range = searchFromEnd
            ? stride(from: bytes.count - sigLen, through: 0, by: -1)
            : stride(from: 0, through: bytes.count - sigLen, by: 1)
        for i in range {
            if bytes[i..<i+sigLen].elementsEqual(sig) { return i }
        }
        return nil
    }
}

// MARK: - DocumentValidationError

enum DocumentValidationError: LocalizedError {
    case corruptedFile
    case missingPart(String)
    case unreadableContent(String)
    case compressedContent(String)
    case contentTypeMissing(String)
    case missingRelationship(String, in: String)
    case slideCountMismatch(expected: Int, actual: Int)
    case sheetCountMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .corruptedFile:
            return "파일이 올바른 ZIP 형식이 아닙니다. 생성 중 오류가 발생했을 수 있습니다."
        case .missingPart(let name):
            return "필수 파트가 누락되었습니다: \(name)"
        case .unreadableContent(let name):
            return "필수 XML 파일을 읽을 수 없습니다: \(name). 파일이 손상되었을 수 있습니다."
        case .compressedContent(let name):
            return "압축된 XML 파일은 검증할 수 없습니다: \(name). Writer 구현을 확인하세요."
        case .contentTypeMissing(let type):
            return "콘텐츠 타입이 선언되지 않았습니다: \(type)"
        case .missingRelationship(let rel, let file):
            return "'\(file)'에 '\(rel)' 관계가 없습니다. 파일 구조가 잘못되었습니다."
        case .slideCountMismatch(let e, let a):
            return "슬라이드 수가 맞지 않습니다 (계획: \(e)장, 실제: \(a)장)"
        case .sheetCountMismatch(let e, let a):
            return "시트 수가 맞지 않습니다 (계획: \(e)개, 실제: \(a)개)"
        }
    }
}
