import Foundation

/// 100% Swift 네이티브로 구현된 BPE(Byte-Pair Encoding) 토크나이저
/// Python 서버에 의존하지 않고 온디바이스에서 텍스트 → token_id 변환 수행
@InferenceActor
final class BPETokenizer {
    private var vocab: [String: Int32] = [:]
    private var merges: [(String, String)] = []
    
    // 특수 토큰
    static let startToken: Int32 = 255
    static let stopToken: Int32  = 0
    static let spaceToken: Int32 = 2
    static let unkToken: Int32   = 1
    static let koLangToken: Int32 = 724  // [ko] 토큰 태그
    
    // 자소 분해를 위한 유니코드 베이스
    private let HANGUL_BASE: UInt32 = 0xAC00
    private let HANGUL_END: UInt32 = 0xD7A3
    
    private let CHOSUNG = ["ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]
    private let JUNGSUNG = ["ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅘ","ㅙ","ㅚ","ㅛ","ㅜ","ㅝ","ㅞ","ㅟ","ㅠ","ㅡ","ㅢ","ㅣ"]
    private let JONGSUNG = ["","ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ","ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]
    
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
    
    // MARK: - 문자열 분해 (Jamo Split)
    private func splitJamo(_ text: String) -> [String] {
        var result: [String] = []
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if value >= HANGUL_BASE && value <= HANGUL_END {
                let offset = value - HANGUL_BASE
                let jong = Int(offset % 28)
                let jung = Int((offset / 28) % 21)
                let cho = Int(offset / 588)
                
                result.append(CHOSUNG[cho])
                result.append(JUNGSUNG[jung])
                if jong > 0 {
                    result.append(JONGSUNG[jong])
                }
            } else {
                result.append(String(scalar))
            }
        }
        return result
    }
    
    // MARK: - BPE Encoding
    func encode(_ text: String) -> [Int32] {
        var tokens: [Int32] = [BPETokenizer.koLangToken, BPETokenizer.startToken]
        
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
        
        tokens.append(BPETokenizer.stopToken)
        return tokens
    }
}
