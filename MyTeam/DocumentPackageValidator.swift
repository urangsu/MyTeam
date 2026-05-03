import Foundation

// MARK: - DocumentPackageValidator
// 생성된 PPTX / XLSX 파일이 최소 필수 OOXML part를 포함하는지 검증한다.
// ZIP stored-mode 파일을 직접 파싱해 Central Directory에서 파일 목록을 추출.

enum DocumentPackageValidator {

    // MARK: - PPTX 검증

    /// PPTX 최소 필수 part 검증.
    /// - Parameters:
    ///   - url: .pptx 파일 경로
    ///   - expectedSlideCount: DeckPlan의 slides.count
    /// - Throws: DocumentValidationError (누락 part / slide 불일치)
    static func validatePPTX(at url: URL, expectedSlideCount: Int) throws {
        let entries = try zipEntryNames(at: url)

        let required: [String] = [
            "[Content_Types].xml",
            "ppt/presentation.xml",
            "ppt/_rels/presentation.xml.rels",
            "ppt/slides/slide1.xml"
        ]
        for part in required {
            guard entries.contains(part) else {
                throw DocumentValidationError.missingPart(part)
            }
        }

        // slide 파일 개수 확인
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
        let entries = try zipEntryNames(at: url)

        let required: [String] = [
            "[Content_Types].xml",
            "xl/workbook.xml",
            "xl/worksheets/sheet1.xml",
            "xl/sharedStrings.xml",
            "xl/styles.xml"
        ]
        for part in required {
            guard entries.contains(part) else {
                throw DocumentValidationError.missingPart(part)
            }
        }

        // 시트 파일 개수 확인
        let sheetFiles = entries.filter {
            $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml")
        }
        guard sheetFiles.count == expectedSheetCount else {
            throw DocumentValidationError.sheetCountMismatch(expected: expectedSheetCount, actual: sheetFiles.count)
        }

        AppLog.info("[Validator] XLSX OK: \(sheetFiles.count)시트, \(entries.count) parts")
    }

    // MARK: - ZIP Central Directory 파싱

    /// ZIP 파일에서 파일명 목록만 추출 (Central Directory 기반).
    /// 순수 Swift, 외부 의존 없음.
    private static func zipEntryNames(at url: URL) throws -> Set<String> {
        let data = try Data(contentsOf: url)
        guard data.count > 22 else { throw DocumentValidationError.corruptedFile }

        // End of Central Directory 시그니처: 0x06054b50 (little-endian)
        let eocdSig: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        guard let eocdOffset = findSignature(eocdSig, in: data, searchFromEnd: true) else {
            throw DocumentValidationError.corruptedFile
        }

        let bytes = [UInt8](data)
        // EOCD: offset 16 = offset of central directory (4 bytes LE)
        let cdOffset = Int(readU32(bytes, at: eocdOffset + 16))
        // EOCD: offset 12 = number of entries (2 bytes LE)
        let entryCount = Int(readU16(bytes, at: eocdOffset + 12))

        var entries: Set<String> = []
        var pos = cdOffset
        let cdSig: [UInt8] = [0x50, 0x4b, 0x01, 0x02]

        for _ in 0..<entryCount {
            guard pos + 46 <= bytes.count else { break }
            guard bytes[pos..<pos+4].elementsEqual(cdSig) else { break }

            let nameLen   = Int(readU16(bytes, at: pos + 28))
            let extraLen  = Int(readU16(bytes, at: pos + 30))
            let commentLen = Int(readU16(bytes, at: pos + 32))
            let nameStart = pos + 46
            let nameEnd   = nameStart + nameLen
            guard nameEnd <= bytes.count else { break }

            if let name = String(bytes: bytes[nameStart..<nameEnd], encoding: .utf8) {
                entries.insert(name)
            }
            pos = nameEnd + extraLen + commentLen
        }
        return entries
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

    /// data 안에서 signature 바이트 배열의 마지막 출현 위치를 반환.
    private static func findSignature(_ sig: [UInt8], in data: Data, searchFromEnd: Bool) -> Int? {
        let bytes = [UInt8](data)
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
    case slideCountMismatch(expected: Int, actual: Int)
    case sheetCountMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .corruptedFile:
            return "파일이 올바른 ZIP 형식이 아닙니다."
        case .missingPart(let name):
            return "필수 파트 누락: \(name)"
        case .slideCountMismatch(let e, let a):
            return "슬라이드 수 불일치 (계획: \(e)장, 실제: \(a)장)"
        case .sheetCountMismatch(let e, let a):
            return "시트 수 불일치 (계획: \(e)개, 실제: \(a)개)"
        }
    }
}
