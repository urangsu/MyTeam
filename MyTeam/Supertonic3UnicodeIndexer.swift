import Foundation

// MARK: - Supertonic3UnicodeIndexer
// Round 249TTS-SPIKE: Character-level tokenizer for Supertonic3.
//
// Loads unicode_indexer.json — a flat array of length 65536.
// Index = Unicode codepoint (U+0000 to U+FFFF)
// Value = model token index (-1 = unsupported, skip)
//
// Python equivalent:
//   self.indexer[ord(char)] -> model index
//   Skips characters where indexer[ord(char)] == -1
//
// Text preprocessing (mirrors Python TextProcessor._preprocess_text):
//   1. NFKD normalization (via String.precomposedStringWithCompatibilityMapping)
//   2. Append period if text does not end with punctuation
//   3. Wrap with language tokens: <lang>text</lang> (if lang != nil)
//
// Output shapes (batch_size=1):
//   text_ids:  [1, T] Int64
//   text_mask: [1, 1, T] Float32 (all 1.0 for single sequence)

struct Supertonic3UnicodeIndexer: Sendable {

    // MARK: - Storage

    /// Flat array: index = unicode codepoint, value = model index (-1 = unsupported)
    private let indexer: [Int]

    // MARK: - Init

    nonisolated init(indexer: [Int]) {
        self.indexer = indexer
    }

    /// Load from unicode_indexer.json at the given URL.
    nonisolated static func load(from url: URL) throws -> Supertonic3UnicodeIndexer {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([Int].self, from: data)
        guard decoded.count >= 256 else {
            throw Supertonic3UnicodeIndexerError.invalidFormat(
                "Expected array of length >= 256, got \(decoded.count)"
            )
        }
        return Supertonic3UnicodeIndexer(indexer: decoded)
    }

    // MARK: - Encode

    /// Convert text to (text_ids, text_mask) tensors for ONNX inference.
    ///
    /// - Parameters:
    ///   - text: Input text (preprocessed or raw)
    ///   - lang: Language code for multilingual wrapping ("en", "ko", "ja", "na", etc.)
    ///           If nil, no language tokens are added (v1 compatibility).
    /// - Returns: `(text_ids, text_mask)` as flat arrays.
    ///   Caller must reshape to [1, T] and [1, 1, T] respectively.
    nonisolated func encode(text: String, lang: String?) throws -> (textIds: [Int64], textMask: [Float], seqLen: Int) {
        let preprocessed = preprocess(text: text, lang: lang)
        var textIds: [Int64] = []

        for scalar in preprocessed.unicodeScalars {
            let cp = Int(scalar.value)
            guard cp < indexer.count else { continue }
            let idx = indexer[cp]
            guard idx >= 0 else { continue }  // -1 = unsupported, skip
            textIds.append(Int64(idx))
        }

        guard !textIds.isEmpty else {
            throw Supertonic3UnicodeIndexerError.emptyTokenSequence(text)
        }

        let seqLen = textIds.count
        let textMask = [Float](repeating: 1.0, count: seqLen)
        return (textIds, textMask, seqLen)
    }

    // MARK: - Validate

    /// Returns unsupported characters in the given text (for user-facing error messages).
    func unsupportedCharacters(in text: String) -> [Character] {
        var result: [Character] = []
        for char in text {
            for scalar in char.unicodeScalars {
                let cp = Int(scalar.value)
                if cp >= indexer.count || indexer[cp] < 0 {
                    result.append(char)
                }
            }
        }
        return result
    }

    // MARK: - Private: Text Preprocessing

    /// Mirrors Python TextProcessor._preprocess_text (simplified).
    /// Full Python preprocessing includes NFKD, emoji removal, abbreviation expansion, etc.
    /// This Swift implementation covers the core steps relevant to character encoding.
    nonisolated private func preprocess(text: String, lang: String?) -> String {
        var result = text

        // Step 1: NFKD-equivalent normalization
        // Swift's decomposedStringWithCompatibilityMapping is NFKD
        result = result.decomposedStringWithCompatibilityMapping

        // Step 2: Trim whitespace
        result = result.trimmingCharacters(in: .whitespaces)

        // Step 3: Add period if text doesn't end with sentence-ending punctuation
        let endPunctuation: Set<Character> = [".", "!", "?", "。", "！", "？", "\n"]
        if !result.isEmpty, let last = result.last, !endPunctuation.contains(last) {
            result += "."
        }

        // Step 4: Wrap with language tokens for multilingual models
        if let lang = lang, !lang.isEmpty {
            result = "<\(lang)>\(result)</\(lang)>"
        }

        return result
    }
}

// MARK: - Errors

enum Supertonic3UnicodeIndexerError: Error, Sendable {
    case invalidFormat(String)
    case emptyTokenSequence(String)
}
