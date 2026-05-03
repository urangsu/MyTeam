import Foundation

// MARK: - XLSXWriter
// OOXML SpreadsheetML (.xlsx) 생성기.
// MiniZipWriter(stored mode)로 ZIP 패키지 조립. 외부 라이브러리 불필요.

final class XLSXWriter {

    func write(plan: WorkbookPlan, to url: URL) throws -> DocumentGenerationResult {
        let zip = MiniZipWriter()
        let sheets = plan.sheets.isEmpty
            ? [SheetPlan(name: plan.title, headers: [], rows: [], summary: nil)]
            : plan.sheets

        // 공유 문자열 테이블 구축
        var strings: [String] = []
        var stringIdx: [String: Int] = [:]
        func si(_ s: String) -> Int {
            if let i = stringIdx[s] { return i }
            let i = strings.count
            strings.append(s); stringIdx[s] = i
            return i
        }

        // 시트마다 cell ref XML 사전 생성 (shared strings 채우기)
        var sheetXMLs: [String] = []
        for sheet in sheets {
            var rows = ""
            // Header row (row 1, bold style index 1)
            if !sheet.headers.isEmpty {
                var cells = ""
                for (col, header) in sheet.headers.enumerated() {
                    let ref = "\(xlsxCol(col + 1))1"
                    let idx = si(header)
                    cells += "<c r=\"\(ref)\" t=\"s\" s=\"1\"><v>\(idx)</v></c>"
                }
                rows += "<row r=\"1\" customFormat=\"1\">\(cells)</row>"
            }
            // Data rows
            for (rowIdx, row) in sheet.rows.enumerated() {
                let rowNum = rowIdx + 2
                var cells = ""
                for (col, val) in row.enumerated() {
                    let ref = "\(xlsxCol(col + 1))\(rowNum)"
                    let idx = si(val)
                    cells += "<c r=\"\(ref)\" t=\"s\"><v>\(idx)</v></c>"
                }
                rows += "<row r=\"\(rowNum)\">\(cells)</row>"
            }
            sheetXMLs.append(rows)
        }

        // [Content_Types].xml
        var sheetOverrides = ""
        for i in 1...sheets.count {
            sheetOverrides += "<Override PartName=\"/xl/worksheets/sheet\(i).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        zip.addEntry(name: "[Content_Types].xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          \(sheetOverrides)
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """)

        // _rels/.rels
        zip.addEntry(name: "_rels/.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """)

        // xl/workbook.xml
        var sheetEls = ""
        for (i, sheet) in sheets.enumerated() {
            sheetEls += "<sheet name=\"\(xmlEsc(sheet.name))\" sheetId=\"\(i + 1)\" r:id=\"rId\(i + 1)\"/>"
        }
        zip.addEntry(name: "xl/workbook.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <bookViews><workbookView firstSheet="0" activeTab="0"/></bookViews>
          <sheets>\(sheetEls)</sheets>
        </workbook>
        """)

        // xl/_rels/workbook.xml.rels
        var wbRels = ""
        for i in 1...sheets.count {
            wbRels += "<Relationship Id=\"rId\(i)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i).xml\"/>"
        }
        let ssRId = sheets.count + 1
        let stRId = sheets.count + 2
        wbRels += "<Relationship Id=\"rId\(ssRId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings\" Target=\"sharedStrings.xml\"/>"
        wbRels += "<Relationship Id=\"rId\(stRId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        zip.addEntry(name: "xl/_rels/workbook.xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(wbRels)
        </Relationships>
        """)

        // 시트마다 worksheet XML
        for (i, sheet) in sheets.enumerated() {
            let frozenPane = sheet.headers.isEmpty ? "" : """
            <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
            """
            let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              \(frozenPane)
              <sheetData>\(sheetXMLs[i])</sheetData>
            </worksheet>
            """
            zip.addEntry(name: "xl/worksheets/sheet\(i + 1).xml", utf8: xml)
        }

        // xl/styles.xml — 기본 스타일 (index 0) + bold header (index 1)
        zip.addEntry(name: "xl/styles.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
          </cellXfs>
        </styleSheet>
        """)

        // xl/sharedStrings.xml
        let ssItems = strings.map { "<si><t>\(xmlEsc($0))</t></si>" }.joined()
        zip.addEntry(name: "xl/sharedStrings.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
             count="\(strings.count)" uniqueCount="\(strings.count)">
          \(ssItems)
        </sst>
        """)

        // docProps/app.xml
        zip.addEntry(name: "docProps/app.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <Application>MyTeam</Application>
          <Sheets>\(sheets.count)</Sheets>
        </Properties>
        """)

        let data = zip.build()
        try data.write(to: url)

        let totalRows = sheets.reduce(0) { $0 + $1.rows.count }
        return DocumentGenerationResult(
            url: url,
            title: plan.title,
            format: .xlsx,
            pageCount: totalRows,
            artifactPath: url.lastPathComponent
        )
    }

    // MARK: - Helpers

    /// 1-based 열 인덱스 → 엑셀 열 문자 (1→A, 26→Z, 27→AA)
    private func xlsxCol(_ col: Int) -> String {
        var n = col, result = ""
        while n > 0 {
            n -= 1
            result = String(UnicodeScalar(65 + (n % 26))!) + result
            n /= 26
        }
        return result
    }

    private func xmlEsc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
