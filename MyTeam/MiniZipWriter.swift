import Foundation

// MARK: - MiniZipWriter
// 순수 Swift ZIP 구현. stored method (압축 없음) 사용 — 외부 라이브러리 불필요.
// OOXML(PPTX/XLSX)은 압축 없는 ZIP으로도 완전히 유효하다.

final class MiniZipWriter {
    private var body = Data()
    private var entries: [(name: String, data: Data, crc: UInt32, localOffset: UInt32)] = []

    // MARK: - Public API

    func addEntry(name: String, utf8 string: String) {
        addEntry(name: name, data: Data(string.utf8))
    }

    func addEntry(name: String, data: Data) {
        let crc    = Self.crc32(data)
        let offset = UInt32(body.count)
        let nameData = Data(name.utf8)

        // Local file header (30 bytes + filename)
        body += le32(0x04034b50)            // signature
        body += le16(20)                    // version needed: 2.0
        body += le16(0)                     // flags
        body += le16(0)                     // compression: stored
        body += le16(0)                     // mod time
        body += le16(0)                     // mod date
        body += le32(crc)
        body += le32(UInt32(data.count))    // compressed = uncompressed for stored
        body += le32(UInt32(data.count))
        body += le16(UInt16(nameData.count))
        body += le16(0)                     // extra field length
        body.append(nameData)
        body.append(data)

        entries.append((name: name, data: data, crc: crc, localOffset: offset))
    }

    func build() -> Data {
        let cdStart = UInt32(body.count)
        var cd = Data()

        for e in entries {
            let nameData = Data(e.name.utf8)
            cd += le32(0x02014b50)               // central dir signature
            cd += le16(0x0314)                   // version made by: Unix 2.0
            cd += le16(20)                       // version needed
            cd += le16(0)                        // flags
            cd += le16(0)                        // stored
            cd += le16(0)                        // mod time
            cd += le16(0)                        // mod date
            cd += le32(e.crc)
            cd += le32(UInt32(e.data.count))
            cd += le32(UInt32(e.data.count))
            cd += le16(UInt16(nameData.count))
            cd += le16(0)                        // extra
            cd += le16(0)                        // comment
            cd += le16(0)                        // disk start
            cd += le16(0)                        // internal attrs
            cd += le32(0)                        // external attrs
            cd += le32(e.localOffset)
            cd.append(nameData)
        }

        let cdSize = UInt32(cd.count)
        let count  = UInt16(entries.count)
        var eocd   = Data()
        eocd += le32(0x06054b50)   // end-of-central-dir signature
        eocd += le16(0)            // disk number
        eocd += le16(0)            // disk with CD start
        eocd += le16(count)        // entries on disk
        eocd += le16(count)        // total entries
        eocd += le32(cdSize)       // CD size
        eocd += le32(cdStart)      // CD offset
        eocd += le16(0)            // comment length

        var result = body
        result.append(cd)
        result.append(eocd)
        return result
    }

    // MARK: - CRC-32

    private static let crcTable: [UInt32] = (0...255).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in data { crc = crcTable[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8) }
        return ~crc
    }

    // MARK: - Little-endian helpers

    private func le16(_ v: UInt16) -> Data {
        Data([UInt8(v & 0xFF), UInt8(v >> 8)])
    }
    private func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
              UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
    }
}

// MARK: - Data += convenience

private func += (lhs: inout Data, rhs: Data) { lhs.append(rhs) }
