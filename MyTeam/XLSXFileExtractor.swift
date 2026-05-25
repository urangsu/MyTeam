import Foundation
import ZIPFoundation

struct XLSXWorksheet: Sendable {
    let sheetNumber: Int
    let sheetName: String
    let rows: [[String]]
}

enum XLSXExtractionError: LocalizedError, Sendable {
    case invalidXLSX
    case noSheetsFound
    case noContentXML
    case invalidXML
    case unsupportedFormat
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidXLSX:
            return "XLSX 파일이 손상되었습니다"
        case .noSheetsFound:
            return "이 XLSX 파일에는 워크시트가 없습니다"
        case .noContentXML:
            return "XLSX에서 콘텐츠를 찾을 수 없습니다"
        case .invalidXML:
            return "XLSX 형식이 잘못되었습니다"
        case .unsupportedFormat:
            return "지원하지 않는 XLSX 형식입니다"
        case .extractionFailed(let detail):
            return "데이터 추출 실패: \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noSheetsFound, .noContentXML:
            return "다른 Excel 파일을 시도해보세요."
        case .invalidXML:
            return "Excel에서 파일을 다시 저장한 후 시도하세요."
        default:
            return nil
        }
    }
}

enum XLSXFileExtractor {
    static func extractText(from url: URL) throws -> String {
        let worksheets = try extractWorksheets(from: url)
        guard !worksheets.isEmpty else {
            throw XLSXExtractionError.noSheetsFound
        }

        let texts = worksheets.map { ws in
            ws.rows.map { row in row.joined(separator: " ") }.joined(separator: "\n")
        }
        return texts.joined(separator: "\n\n")
    }

    static func extractMarkdown(from url: URL) throws -> String {
        let worksheets = try extractWorksheets(from: url)
        guard !worksheets.isEmpty else {
            throw XLSXExtractionError.noSheetsFound
        }

        let markdown = worksheets.map { worksheetToMarkdown($0) }.joined(separator: "\n\n---\n\n")
        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractWorksheets(from url: URL) throws -> [XLSXWorksheet] {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw XLSXExtractionError.invalidXLSX
        }

        var sharedStrings: [String] = []
        if let sharedStringsEntry = archive["xl/sharedStrings.xml"] {
            var data = Data()
            _ = try archive.extract(sharedStringsEntry, consumer: { chunk in
                data.append(chunk)
            })
            sharedStrings = try parseSharedStrings(data)
        }

        var worksheets: [XLSXWorksheet] = []
        var sheetNumber = 1

        while let sheetEntry = archive["xl/worksheets/sheet\(sheetNumber).xml"] {
            var data = Data()
            _ = try archive.extract(sheetEntry, consumer: { chunk in
                data.append(chunk)
            })

            let rows = try parseWorksheet(data, sharedStrings: sharedStrings)
            worksheets.append(XLSXWorksheet(
                sheetNumber: sheetNumber,
                sheetName: "Sheet\(sheetNumber)",
                rows: rows
            ))

            sheetNumber += 1
        }

        guard !worksheets.isEmpty else {
            throw XLSXExtractionError.noSheetsFound
        }

        return worksheets
    }

    private static func parseSharedStrings(_ data: Data) throws -> [String] {
        var strings: [String] = []

        let parser = XMLParser(data: data)
        var currentString = ""
        var inString = false

        class StringParserDelegate: NSObject, XMLParserDelegate {
            var strings: [String] = []
            var currentString = ""
            var inStringTag = false

            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName == "si" {
                    inStringTag = true
                    currentString = ""
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                if inStringTag {
                    currentString += string
                }
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "si" && inStringTag {
                    strings.append(currentString)
                    inStringTag = false
                    currentString = ""
                }
            }
        }

        let delegate = StringParserDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            throw XLSXExtractionError.invalidXML
        }

        return delegate.strings
    }

    private static func parseWorksheet(_ data: Data, sharedStrings: [String]) throws -> [[String]] {
        var rows: [[String]] = []

        let parser = XMLParser(data: data)

        class WorksheetParserDelegate: NSObject, XMLParserDelegate {
            var rows: [[String]] = []
            var currentRow: [String] = []
            var currentCell = ""
            var inCellValue = false
            var sharedStrings: [String]

            init(sharedStrings: [String]) {
                self.sharedStrings = sharedStrings
            }

            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName == "row" {
                    currentRow = []
                } else if elementName == "c" {
                    currentCell = ""
                    inCellValue = true
                } else if elementName == "v" {
                    inCellValue = true
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                if inCellValue {
                    currentCell += string.trimmingCharacters(in: .whitespaces)
                }
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "c" || elementName == "v" {
                    let cellValue: String
                    if let index = Int(currentCell), index < sharedStrings.count {
                        cellValue = sharedStrings[index]
                    } else {
                        cellValue = currentCell
                    }
                    currentRow.append(cellValue)
                    inCellValue = false
                } else if elementName == "row" && !currentRow.isEmpty {
                    rows.append(currentRow)
                }
            }
        }

        let delegate = WorksheetParserDelegate(sharedStrings: sharedStrings)
        parser.delegate = delegate

        guard parser.parse() else {
            throw XLSXExtractionError.invalidXML
        }

        return delegate.rows
    }

    private static func worksheetToMarkdown(_ sheet: XLSXWorksheet) -> String {
        guard !sheet.rows.isEmpty else {
            return ""
        }

        var markdown: [String] = []

        if sheet.sheetNumber > 1 {
            markdown.append("## \(sheet.sheetName)")
            markdown.append("")
        }

        let maxCols = sheet.rows.map { $0.count }.max() ?? 0
        guard maxCols > 0 else {
            return ""
        }

        for (index, row) in sheet.rows.enumerated() {
            var paddedRow = row
            while paddedRow.count < maxCols {
                paddedRow.append("")
            }

            let markdownRow = "| " + paddedRow.joined(separator: " | ") + " |"
            markdown.append(markdownRow)

            if index == 0 {
                let separator = "| " + Array(repeating: "---", count: maxCols).joined(separator: " | ") + " |"
                markdown.append(separator)
            }
        }

        return markdown.joined(separator: "\n")
    }
}
