import Foundation

// ============================================================
// HangulDecomposer.swift
// 한글 문자를 음소(Phoneme) 키로 분해합니다.
//
// 동작 원리:
//   한글 유니코드 = 0xAC00 + (초성 × 21 + 중성) × 28 + 종성
//   → 각 글자에서 중성(모음)을 추출해 phoneme 키로 변환
//   → AnimalTTSManager가 이 키로 WAV 파일을 찾아 재생
// ============================================================

struct HangulDecomposer {

    // MARK: - 중성(모음) → phoneme 파일 키 매핑
    // generate_phonemes.sh에서 생성한 WAV 파일명과 일치해야 합니다
    private static let vowelToPhoneme: [Int: String] = [
        0:  "a",    // ㅏ
        1:  "ae",   // ㅐ
        2:  "ya",   // ㅑ
        3:  "yae",  // ㅒ
        4:  "eo",   // ㅓ
        5:  "e",    // ㅔ
        6:  "yeo",  // ㅕ
        7:  "ye",   // ㅖ
        8:  "o",    // ㅗ
        9:  "wa",   // ㅘ
        10: "wae",  // ㅙ
        11: "oe",   // ㅚ
        12: "yo",   // ㅛ
        13: "u",    // ㅜ
        14: "wo",   // ㅝ
        15: "we",   // ㅞ
        16: "wi",   // ㅟ
        17: "yu",   // ㅠ
        18: "eu",   // ㅡ
        19: "ui",   // ㅢ
        20: "i",    // ㅣ
    ]


    // 초성 인덱스 → 자음 접두사 (정확한 매핑)
    private static let chosungToPrefix: [Int: String] = [
        0:  "k",    // ㄱ
        1:  "k",    // ㄲ (된소리 → 같은 음으로)
        2:  "n",    // ㄴ
        3:  "t",    // ㄷ
        4:  "t",    // ㄸ
        5:  "r",    // ㄹ
        6:  "m",    // ㅁ
        7:  "b",    // ㅂ
        8:  "b",    // ㅃ
        9:  "s",    // ㅅ
        10: "s",    // ㅆ
        11: "",     // ㅇ (무음 초성)
        12: "j",    // ㅈ
        13: "j",    // ㅉ
        14: "ch",   // ㅊ
        15: "k",    // ㅋ
        16: "t",    // ㅌ
        17: "b",    // ㅍ
        18: "h",    // ㅎ
    ]

    // MARK: - 텍스트 → phoneme 키 배열 변환
    /// "안녕하세요" → ["a", "yeo", "ha", "se", "yo"]
    static func decompose(_ text: String) -> [String] {
        var result: [String] = []

        for char in text {
            let scalar = char.unicodeScalars.first!.value

            // 한글 완성형 범위: 0xAC00 ~ 0xD7A3
            if scalar >= 0xAC00 && scalar <= 0xD7A3 {
                let offset = Int(scalar - 0xAC00)
                let chosung  = offset / (21 * 28)   // 초성
                let jungsung = (offset % (21 * 28)) / 28  // 중성(모음)
                // let jongsung = offset % 28         // 종성 (현재 미사용)

                // 초성 + 중성 조합 파일이 있으면 우선 사용 (na, ma, ra ...)
                if let prefix = chosungToPrefix[chosung],
                   !prefix.isEmpty,
                   let vowelKey = vowelToPhoneme[jungsung] {
                    let combinedKey = prefix + vowelKey  // "na", "mi", "ra" 등
                    // 조합 파일 존재 여부는 AnimalTTSManager에서 확인
                    result.append(combinedKey)
                } else if let vowelKey = vowelToPhoneme[jungsung] {
                    // 초성 무음(ㅇ) 또는 매핑 없을 때 → 모음만 사용
                    result.append(vowelKey)
                }

            } else if scalar >= 0x61 && scalar <= 0x7A {
                // 영문 소문자 a-z → 알파벳 그대로
                result.append(String(char))

            } else if scalar >= 0x41 && scalar <= 0x5A {
                // 영문 대문자 A-Z → 소문자로
                result.append(String(char).lowercased())

            } else if char == " " || char == "\n" {
                // 공백 → nil (쉬어가기)
                result.append("pause")

            }
            // 숫자, 특수문자 등은 건너뜀
        }

        return result
    }
}
