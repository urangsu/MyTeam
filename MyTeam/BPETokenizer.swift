import Foundation

/// 100% Swift 네이티브로 구현된 BPE(Byte-Pair Encoding) 토크나이저
/// Python 서버에 의존하지 않고 온디바이스에서 텍스트 → token_id 변환 수행

final class BPETokenizer {
    private var vocab: [String: Int32] = [:]
    private var merges: [(String, String)] = []
    
    // 특수 토큰
    static let startToken: Int32 = 255
    static let stopToken: Int32  = 0
    static let spaceToken: Int32 = 2
    static let unkToken: Int32   = 1
    static let koLangToken: Int32 = 724  // [ko] 토큰 태그
    
    private let HANGUL_BASE: UInt32 = 0xAC00
    private let HANGUL_END: UInt32 = 0xD7A3
    
    init() throws {
        // 번들 혹은 특정 경로에서 JSON 로드
        let url: URL
        if let bundleUrl = Bundle.main.url(forResource: "grapheme_mtl_merged_expanded_v1", withExtension: "json", subdirectory: "onnx_models") {
            url = bundleUrl
        } else {
            let devPath = "/Users/su/Desktop/TTS맨/chatterbox/onnx_models/grapheme_mtl_merged_expanded_v1.json"
            guard FileManager.default.fileExists(atPath: devPath) else {
                throw NSError(domain: "BPETokenizer", code: 404, userInfo: [NSLocalizedDescriptionKey: "grapheme_mtl_merged_expanded_v1.json 없음"])
            }
            url = URL(fileURLWithPath: devPath)
        }
        
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = json["model"] as? [String: Any] else {
            throw NSError(domain: "BPETokenizer", code: 500, userInfo: [NSLocalizedDescriptionKey: "JSON 파싱 실패"])
        }
        
        // Vocab 로드
        if let vocabDict = model["vocab"] as? [String: Int] {
            vocab = vocabDict.mapValues { Int32($0) }
        }
        
        // Merges 로드
        if let mergeList = model["merges"] as? [String] {
            merges = mergeList.compactMap { pair -> (String, String)? in
                let parts = pair.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return (String(parts[0]), String(parts[1]))
            }
        }
    }
    
    private func splitJamo(_ text: String) -> [String] {
        var result: [String] = []
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if value >= HANGUL_BASE && value <= HANGUL_END {
                let offset = value - HANGUL_BASE
                let cho = (offset / (21 * 28))
                let jung = ((offset % (21 * 28)) / 28)
                let jong = (offset % 28)
                
                // ✅ 치명적 버그 수정:
                // 기존에는 Compatibility Jamo (U+3131 'ㄱ')를 사용했으나,
                // Python 원본은 Standard Jamo (U+1100 'ᄀ')를 사용하여 BPE를 학습함.
                // 텍스트가 모두 [UNK]로 변환되어 모델이 외계어를 내뱉던 문제의 근본 원인.
                if let choScalar = UnicodeScalar(0x1100 + cho) {
                    result.append(String(choScalar))
                }
                if let jungScalar = UnicodeScalar(0x1161 + jung) {
                    result.append(String(jungScalar))
                }
                if jong > 0 {
                    if let jongScalar = UnicodeScalar(0x11A7 + jong) {
                        result.append(String(jongScalar))
                    }
                }
            } else {
                result.append(String(scalar))
            }
        }
        return result
    }
    
    // MARK: - Korean G2P Romanizer
    static func containsHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
    }

    /// 한국어 발음 기반 로마자 변환 (연음화 포함).
    /// T3 모델이 영어 학습 기반이므로 로마자 입력 시 EOS 발견율이 크게 향상됨.
    static func romanizeKorean(_ text: String) -> String {
        // Revised Romanization of Korean – 초/중/종성 발음 테이블
        let CHO:  [String] = ["g","kk","n","d","tt","r","m","b","pp","s","ss","","j","jj","ch","k","t","p","h"]
        let JUNG: [String] = ["a","ae","ya","yae","eo","e","yeo","ye","o","wa","wae","oe","yo","u","wo","we","wi","yu","eu","eui","i"]
        let JONG: [String] = ["","k","k","k","n","n","n","t","l","k","m","l","l","l","p","l","m","p","p","t","t","ng","t","t","k","t","p","t"]
        // 연음화: 종성 인덱스 → 이동할 때의 초성 인덱스
        let JONG_TO_CHO: [Int] = [11,0,1,9,2,12,18,3,5,0,6,7,9,16,17,18,6,7,9,9,10,11,12,14,15,16,17,18]
        // 연음화 후 남는 종성 인덱스 (복합 종성)
        let JONG_REMNANT: [Int] = [0,0,0,1,0,4,4,0,0,8,8,8,8,8,8,8,0,0,17,0,0,0,0,0,0,0,0,0]
        let BASE: UInt32 = 0xAC00

        struct Syl { var cho, jung, jong: Int }
        enum Elem { case syl(Syl); case ch(Character) }

        // 1. 음절 분해
        var elems: [Elem] = text.map { ch in
            if let s = ch.unicodeScalars.first, s.value >= BASE, s.value <= 0xD7A3 {
                let off = s.value - BASE
                return .syl(Syl(cho: Int(off/588), jung: Int((off%588)/28), jong: Int(off%28)))
            }
            return .ch(ch)
        }

        // 2. 연음화 (종성 + ㅇ초성 → 종성이 다음 초성으로 이동)
        for i in 0..<(elems.count - 1) {
            guard case .syl(var cur) = elems[i], cur.jong != 0,
                  case .syl(var nxt) = elems[i+1], nxt.cho == 11 else { continue }
            nxt.cho  = JONG_TO_CHO[cur.jong]
            cur.jong = JONG_REMNANT[cur.jong]
            elems[i]   = .syl(cur)
            elems[i+1] = .syl(nxt)
        }

        // 3. 로마자 조합
        return elems.map { elem -> String in
            switch elem {
            case .syl(let s): return CHO[s.cho] + JUNG[s.jung] + JONG[s.jong]
            case .ch(let c):  return String(c)
            }
        }.joined()
    }

    // MARK: - BPE Encoding
    func encode(_ text: String, addLanguageTag: Bool = true) -> [Int32] {
        // ✅ Python T3 토크나이저의 실제 동작 + F.pad 패딩까지 완벽히 일치시켜야 함
        // Python 최종 text_tokens:
        // [255(sot), 6563(exaggeration), 255(sot), 724(ko), ...text..., 0(eot), 6561(start_speech), 6561(start_speech), 0(eot)]
        var tokens: [Int32] = [255, 6563, 255]
        if addLanguageTag { tokens.append(724) } // [ko] token
        
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for (idx, word) in words.enumerated() {
            if idx > 0 { tokens.append(BPETokenizer.spaceToken) }
            
            // 1. 단어를 문자 & 자소 단위로 쪼개기
            var symbols = splitJamo(word)
            
            // 2. BPE Merges 반복 적용
            var changed = true
            while changed && symbols.count > 1 {
                changed = false
                // 우선순위가 가장 높은(배열 앞쪽) Merge 규칙을 찾아 병합
                var bestMergeIndex: Int? = nil
                var bestMergePair: (String, String)? = nil
                var minRank = Int.max
                
                for i in 0..<(symbols.count - 1) {
                    let pair = (symbols[i], symbols[i+1])
                    if let rank = merges.firstIndex(where: { $0.0 == pair.0 && $0.1 == pair.1 }) {
                        if rank < minRank {
                            minRank = rank
                            bestMergeIndex = i
                            bestMergePair = pair
                        }
                    }
                }
                
                if let i = bestMergeIndex, let pair = bestMergePair {
                    symbols[i] = pair.0 + pair.1
                    symbols.remove(at: i + 1)
                    changed = true
                }
            }
            
            // 3. Vocab 매핑
            let outputIds = symbols.map { vocab[$0] ?? BPETokenizer.unkToken }
            tokens.append(contentsOf: outputIds)
        }
        
        // 끝 부분에도 Python과 동일한 특수 토큰 시퀀스 추가
        tokens.append(contentsOf: [0, 6561, 6561, 0])
        return tokens
    }
}
