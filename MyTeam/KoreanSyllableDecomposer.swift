import Foundation

struct KoreanSyllableParts: Sendable {
    let original: Character
    let initialIndex: Int?
    let medialIndex: Int?
    let finalIndex: Int?
    let isHangulSyllable: Bool
}

enum KoreanSyllableDecomposer {
    static let hangulBase: UInt32 = 0xAC00
    static let hangulEnd: UInt32 = 0xD7A3
    static let medialCount = 21
    static let finalCount = 28

    static func decompose(_ char: Character) -> KoreanSyllableParts {
        guard let scalar = char.unicodeScalars.first,
              isHangulSyllable(scalar.value)
        else {
            return KoreanSyllableParts(
                original: char,
                initialIndex: nil,
                medialIndex: nil,
                finalIndex: nil,
                isHangulSyllable: false
            )
        }

        let sIndex = Int(scalar.value - hangulBase)
        let initial = sIndex / (medialCount * finalCount)
        let medial = (sIndex % (medialCount * finalCount)) / finalCount
        let final = sIndex % finalCount

        return KoreanSyllableParts(
            original: char,
            initialIndex: initial,
            medialIndex: medial,
            finalIndex: final,
            isHangulSyllable: true
        )
    }

    static func isHangulSyllable(_ scalar: UInt32) -> Bool {
        scalar >= hangulBase && scalar <= hangulEnd
    }
}
