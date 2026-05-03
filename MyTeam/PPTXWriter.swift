import Foundation

// MARK: - PPTXWriter
// OOXML PresentationML (.pptx) 생성기.
// MiniZipWriter(stored mode)로 ZIP 패키지 조립. 외부 라이브러리 불필요.
// 좌표 단위: EMU (English Metric Unit). 1 inch = 914400 EMU.
// 표준 슬라이드: 9144000 × 5143500 EMU (= 10 × 7.5 inch @ 96 DPI)

final class PPTXWriter {

    func write(plan: DeckPlan, to url: URL) throws -> DocumentGenerationResult {
        let zip = MiniZipWriter()
        let slides: [SlidePlan]
        if plan.slides.isEmpty {
            slides = [(try? SlidePlan(from: EmptySlideDecoder(title: plan.title)))].compactMap { $0 }
        } else {
            slides = plan.slides
        }

        addContentTypes(zip: zip, slideCount: slides.count)
        addRootRels(zip: zip)
        addPresentation(zip: zip, plan: plan, slideCount: slides.count)
        addPresentationRels(zip: zip, slideCount: slides.count)
        addSlideMaster(zip: zip)
        addSlideMasterRels(zip: zip)
        addSlideLayout(zip: zip)
        addSlideLayoutRels(zip: zip)
        addTheme(zip: zip)
        addDocProps(zip: zip, title: plan.title)

        for (i, slide) in slides.enumerated() {
            addSlide(zip: zip, slide: slide, index: i + 1)
            addSlideRels(zip: zip, index: i + 1)
        }

        let data = zip.build()
        try data.write(to: url)

        return DocumentGenerationResult(
            url: url,
            title: plan.title,
            format: .pptx,
            pageCount: slides.count,
            artifactPath: url.lastPathComponent
        )
    }

    // MARK: - Package parts

    private func addContentTypes(zip: MiniZipWriter, slideCount: Int) {
        var overrides = ""
        for i in 1...slideCount {
            overrides += "<Override PartName=\"/ppt/slides/slide\(i).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
        }
        zip.addEntry(name: "[Content_Types].xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
          <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
          <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
          \(overrides)
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """)
    }

    private func addRootRels(zip: MiniZipWriter) {
        zip.addEntry(name: "_rels/.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """)
    }

    private func addPresentation(zip: MiniZipWriter, plan: DeckPlan, slideCount: Int) {
        var sldIdLst = ""
        for i in 0..<slideCount {
            sldIdLst += "<p:sldId id=\"\(256 + i)\" r:id=\"rId\(i + 2)\"/>"
        }
        zip.addEntry(name: "ppt/presentation.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
          <p:sldSz cx="9144000" cy="5143500" type="screen4x3"/>
          <p:notesSz cx="6858000" cy="9144000"/>
          <p:sldIdLst>\(sldIdLst)</p:sldIdLst>
        </p:presentation>
        """)
    }

    private func addPresentationRels(zip: MiniZipWriter, slideCount: Int) {
        var rels = "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/>"
        for i in 0..<slideCount {
            rels += "<Relationship Id=\"rId\(i + 2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(i + 1).xml\"/>"
        }
        zip.addEntry(name: "ppt/_rels/presentation.xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(rels)
        </Relationships>
        """)
    }

    private func addSlideMaster(zip: MiniZipWriter) {
        zip.addEntry(name: "ppt/slideMasters/slideMaster1.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                     xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
              <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
            </p:spTree>
          </p:cSld>
          <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
          <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
          <p:txStyles>
            <p:titleStyle><a:lvl1pPr algn="ctr"><a:defRPr lang="ko-KR" sz="4400" b="1"/></a:lvl1pPr></p:titleStyle>
            <p:bodyStyle><a:lvl1pPr><a:defRPr lang="ko-KR" sz="2800"/></a:lvl1pPr></p:bodyStyle>
            <p:otherStyle><a:lvl1pPr><a:defRPr lang="ko-KR"/></a:lvl1pPr></p:otherStyle>
          </p:txStyles>
        </p:sldMaster>
        """)
    }

    private func addSlideMasterRels(zip: MiniZipWriter) {
        zip.addEntry(name: "ppt/slideMasters/_rels/slideMaster1.xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
        </Relationships>
        """)
    }

    private func addSlideLayout(zip: MiniZipWriter) {
        zip.addEntry(name: "ppt/slideLayouts/slideLayout1.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                     xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                     type="obj" preserve="1">
          <p:cSld name="Title and Content">
            <p:spTree>
              <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
              <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
              <p:sp>
                <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
                <p:spPr><a:xfrm><a:off x="457200" y="274638"/><a:ext cx="8229600" cy="1143000"/></a:xfrm></p:spPr>
                <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
              </p:sp>
              <p:sp>
                <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
                <p:spPr><a:xfrm><a:off x="457200" y="1600200"/><a:ext cx="8229600" cy="3429000"/></a:xfrm></p:spPr>
                <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
              </p:sp>
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sldLayout>
        """)
    }

    private func addSlideLayoutRels(zip: MiniZipWriter) {
        zip.addEntry(name: "ppt/slideLayouts/_rels/slideLayout1.xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """)
    }

    private func addTheme(zip: MiniZipWriter) {
        zip.addEntry(name: "ppt/theme/theme1.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
          <a:themeElements>
            <a:clrScheme name="Office">
              <a:dk1><a:sysClr lastClr="000000" val="windowText"/></a:dk1>
              <a:lt1><a:sysClr lastClr="FFFFFF" val="window"/></a:lt1>
              <a:dk2><a:srgbClr val="44546A"/></a:dk2>
              <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
              <a:accent1><a:srgbClr val="4472C4"/></a:accent1>
              <a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
              <a:accent3><a:srgbClr val="A9D18E"/></a:accent3>
              <a:accent4><a:srgbClr val="FFC000"/></a:accent4>
              <a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
              <a:accent6><a:srgbClr val="70AD47"/></a:accent6>
              <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
              <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
            </a:clrScheme>
            <a:fontScheme name="Office">
              <a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface="맑은 고딕"/><a:cs typeface=""/></a:majorFont>
              <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface="맑은 고딕"/><a:cs typeface=""/></a:minorFont>
            </a:fontScheme>
            <a:fmtScheme name="Office">
              <a:fillStyleLst>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="50000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="50000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>
                <a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="100000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="100000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>
              </a:fillStyleLst>
              <a:lnStyleLst>
                <a:ln w="6350" cap="flat" cmpd="sng"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
                <a:ln w="12700" cap="flat" cmpd="sng"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
                <a:ln w="19050" cap="flat" cmpd="sng"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
              </a:lnStyleLst>
              <a:effectStyleLst>
                <a:effectStyle><a:effectLst/></a:effectStyle>
                <a:effectStyle><a:effectLst/></a:effectStyle>
                <a:effectStyle><a:effectLst><a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0"><a:srgbClr val="000000"><a:alpha val="35000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle>
              </a:effectStyleLst>
              <a:bgFillStyleLst>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"><a:tint val="95000"/></a:schemeClr></a:solidFill>
                <a:gradFill rotWithShape="1"><a:gsLst><a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="93000"/></a:schemeClr></a:gs><a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="98000"/></a:schemeClr></a:gs></a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>
              </a:bgFillStyleLst>
            </a:fmtScheme>
          </a:themeElements>
        </a:theme>
        """)
    }

    private func addDocProps(zip: MiniZipWriter, title: String) {
        zip.addEntry(name: "docProps/app.xml", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <Application>MyTeam</Application>
          <PresentationFormat>Custom</PresentationFormat>
          <Slides>\(0)</Slides>
        </Properties>
        """)
    }

    // MARK: - Slide XML

    private func addSlide(zip: MiniZipWriter, slide: SlidePlan, index: Int) {
        let titleXml = txBody(paragraphs: [plainPara(slide.title)], isBig: true)
        let contentXml: String

        if let bullets = slide.bullets, !bullets.isEmpty {
            let paras = bullets.map { bulletPara($0) }.joined()
            contentXml = txBody(paragraphs: [paras], isBig: false)
        } else if let content = slide.content, !content.isEmpty {
            // 줄바꿈 → 단락 분리
            let lines = content.components(separatedBy: "\n")
            let paras = lines.map { plainPara($0) }.joined()
            contentXml = txBody(paragraphs: [paras], isBig: false)
        } else {
            contentXml = txBody(paragraphs: [plainPara("")], isBig: false)
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
               xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
              <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
              <p:sp>
                <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
                <p:spPr/>
                \(titleXml)
              </p:sp>
              <p:sp>
                <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
                <p:spPr/>
                \(contentXml)
              </p:sp>
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
        zip.addEntry(name: "ppt/slides/slide\(index).xml", utf8: xml)
    }

    private func addSlideRels(zip: MiniZipWriter, index: Int) {
        zip.addEntry(name: "ppt/slides/_rels/slide\(index).xml.rels", utf8: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        </Relationships>
        """)
    }

    // MARK: - XML helpers

    private func txBody(paragraphs: [String], isBig: Bool) -> String {
        "<p:txBody><a:bodyPr/><a:lstStyle/>\(paragraphs.joined())</p:txBody>"
    }

    private func plainPara(_ text: String) -> String {
        "<a:p><a:r><a:t>\(xmlEsc(text))</a:t></a:r></a:p>"
    }

    private func bulletPara(_ text: String) -> String {
        "<a:p><a:pPr marL=\"342900\" indent=\"-342900\"><a:buChar char=\"•\"/></a:pPr><a:r><a:t>\(xmlEsc(text))</a:t></a:r></a:p>"
    }

    private func xmlEsc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - EmptySlideDecoder helper

private struct EmptySlideDecoder: Decoder {
    let title: String
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<K: CodingKey>(keyedBy type: K.Type) throws -> KeyedDecodingContainer<K> {
        KeyedDecodingContainer(EmptySlideContainer(title: title))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { fatalError() }
    func singleValueContainer() throws -> SingleValueDecodingContainer { fatalError() }
}

private struct EmptySlideContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    let title: String
    var codingPath: [CodingKey] = []
    var allKeys: [K] = []
    func contains(_ key: K) -> Bool { key.stringValue == "title" }
    func decodeNil(forKey key: K) throws -> Bool { true }
    func decode(_ type: String.Type, forKey key: K) throws -> String {
        key.stringValue == "title" ? title : ""
    }
    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable { fatalError() }
    func nestedContainer<NK>(keyedBy type: NK.Type, forKey key: K) throws -> KeyedDecodingContainer<NK> { fatalError() }
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer { fatalError() }
    func superDecoder() throws -> Decoder { fatalError() }
    func superDecoder(forKey key: K) throws -> Decoder { fatalError() }
}
