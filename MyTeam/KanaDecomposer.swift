import Foundation

// ============================================================
// KanaDecomposer.swift
// 일본어 히라가나/가타카나 → 음소 키 변환
//
// 사용법:
//   KanaDecomposer.decompose("ありがとう") → ["a", "ri", "ga", "to", "u"]
//
// ElevenLabs로 생성한 WAV 파일명 규칙:
//   bright_female/ja/a.wav, bright_female/ja/ri.wav, bright_female/ja/ga.wav ...
// ============================================================

enum KanaDecomposer {

    // 히라가나 → 로마자 음소 매핑
    private static let hiraganaMap: [Character: String] = [
        // 기본 모음
        "あ": "a",  "い": "i",  "う": "u",  "え": "e",  "お": "o",
        // か행
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        // さ행
        "さ": "sa", "し": "shi","す": "su", "せ": "se", "そ": "so",
        // た행
        "た": "ta", "ち": "chi","つ": "tsu","て": "te", "と": "to",
        // な행
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        // は행
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        // ま행
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        // や행
        "や": "ya", "ゆ": "yu", "よ": "yo",
        // ら행
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        // わ행
        "わ": "wa", "を": "wo",
        // ん
        "ん": "n",
        // が행
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        // ざ행
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        // だ행
        "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
        // ば행
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        // ぱ행
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "페": "pe", "ぽ": "po",
        // 작은 글자 (앞 음소에 붙음 — 단독 재생 불가, 건너뜀)
        "っ": "",   "ー": "",
    ]

    // 가타카나 → 히라가나 변환 (코드 포인트 차이 0x60)
    private static func katakanaToHiragana(_ ch: Character) -> Character? {
        let scalar = ch.unicodeScalars.first!.value
        guard scalar >= 0x30A1 && scalar <= 0x30F6 else { return nil }
        return Character(UnicodeScalar(scalar - 0x60)!)
    }

    /// 일본어 텍스트를 음소 키 배열로 변환
    static func decompose(_ text: String) -> [String] {
        var result: [String] = []
        for ch in text {
            // 히라가나 직접 조회
            if let phoneme = hiraganaMap[ch], !phoneme.isEmpty {
                result.append(phoneme)
                continue
            }
            // 가타카나 → 히라가나 변환 후 조회
            if let hira = katakanaToHiragana(ch),
               let phoneme = hiraganaMap[hira], !phoneme.isEmpty {
                result.append(phoneme)
                continue
            }
            // 기타 문자 (한자, 알파벳, 숫자 등) — 건너뜀
        }
        return result.isEmpty ? ["a"] : result
    }
}
