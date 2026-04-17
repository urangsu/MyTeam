// ChatterboxPipeline.swift
// Full Chatterbox TTS pipeline: text (Korean) → audio waveform
//
// Pipeline:
//   1. Load safetensors weights
//   2. VoiceEncoder: ref_wav (16kHz) → speaker_emb (256-dim)
//   3. Text tokenizer: Korean text → token ids
//   4. T3: text_tokens + speaker_emb → speech_tokens
//   5. HiFTGenerator: speech_tokens + ref_mel → audio waveform
//   6. Write WAV file

import Foundation
import MLX
import MLXNN
import MLXRandom
import MLXFFT

// MARK: - Weight Loading Helpers

/// Load safetensors file and strip a given key prefix.
/// Example: prefix "ve." on key "ve.lstm.layers.0.Wx" → "lstm.layers.0.Wx"
func loadWeights(from url: URL) throws -> [String: MLXArray] {
    return try MLX.loadArrays(url: url)
}

/// Filter weights by prefix, stripping it from the keys.
func filterWeights(_ weights: [String: MLXArray], prefix: String) -> [String: MLXArray] {
    var out = [String: MLXArray]()
    for (key, val) in weights {
        if key.hasPrefix(prefix) {
            let stripped = String(key.dropFirst(prefix.count))
            out[stripped] = val
        }
    }
    return out
}

// MARK: - Korean Text Tokenizer

/// Minimal BPE tokenizer for Korean (multilingual Chatterbox).
/// Reads tokenizer.json from disk and implements:
///   1. Korean hangul decomposition (syllable → jamo)
///   2. Language token prefix [ko]
///   3. Space → [SPACE] replacement
///   4. BPE tokenization using vocab + merge rules
final class KoreanBPETokenizer {
    let vocab: [String: Int]       // token → id
    let merges: [(String, String)] // ordered merge pairs
    let spaceToken = "[SPACE]"
    let sotToken   = "[START]"     // id = 255
    let eotToken   = "[STOP]"      // id = 0

    init(tokenizerJSONURL: URL) throws {
        let data = try Data(contentsOf: tokenizerJSONURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = json["model"] as? [String: Any],
              let rawVocab = model["vocab"] as? [String: Int],
              let rawMerges = model["merges"] as? [String]
        else {
            throw NSError(domain: "Tokenizer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid tokenizer.json"])
        }
        vocab = rawVocab
        merges = rawMerges.compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), String(parts[1]))
        }
    }

    // MARK: Korean normalization

    /// Decompose a Hangul syllable into its constituent jamo characters.
    private func decomposeHangul(_ char: Character) -> String {
        let scalar = char.unicodeScalars.first!.value
        guard 0xAC00 <= scalar, scalar <= 0xD7AF else { return String(char) }
        let base = scalar - 0xAC00
        let initial = Unicode.Scalar(0x1100 + base / (21 * 28))!
        let medial  = Unicode.Scalar(0x1161 + (base % (21 * 28)) / 28)!
        let finalIdx = base % 28
        let final_: String = finalIdx > 0
            ? String(Unicode.Scalar(0x11A7 + finalIdx)!)
            : ""
        return String(initial) + String(medial) + final_
    }

    /// Full Korean text normalization: decompose syllables, lowercase, strip.
    func normalizeKorean(_ text: String) -> String {
        let lowercased = text.lowercased()
        return lowercased.unicodeScalars.map { s -> String in
            let char = Character(s)
            return decomposeHangul(char)
        }.joined()
    }

    // MARK: BPE

    /// Apply BPE merge rules to a list of tokens.
    private func applyBPE(_ tokens: [String]) -> [String] {
        var current = tokens
        for (left, right) in merges {
            var next = [String]()
            var i = 0
            while i < current.count {
                if i + 1 < current.count,
                   current[i] == left, current[i + 1] == right {
                    next.append(left + right)
                    i += 2
                } else {
                    next.append(current[i])
                    i += 1
                }
            }
            current = next
        }
        return current
    }

    // MARK: Encode

    /// Encode Korean text to token ids.
    /// - Parameters:
    ///   - text: raw Korean text
    ///   - addSOT: prepend start-of-text token (id=255)
    ///   - addEOT: append end-of-text token (id=0)
    /// - Returns: [Int32] token ids
    func encode(_ text: String, addSOT: Bool = true, addEOT: Bool = true) -> [Int32] {
        // 1. Normalize Korean
        let normalized = normalizeKorean(text)

        // 2. Prepend language token, replace spaces
        let withLang  = "[ko]" + normalized
        let withSpace = withLang.replacingOccurrences(of: " ", with: spaceToken)

        // 3. Initial character-level tokens (each Unicode scalar is one token)
        // Split by [SPACE] and [XX] special tokens first, then char-split the rest
        var rawTokens = splitWithSpecials(withSpace)

        // 4. Apply BPE merges
        let bpeTokens = applyBPE(rawTokens)

        // 5. Lookup in vocabulary (unknown → id 1 = [UNK])
        var ids = bpeTokens.map { vocab[$0] ?? 1 }

        // 6. Wrap with SOT/EOT
        if addSOT { ids.insert(vocab[sotToken] ?? 255, at: 0) }
        if addEOT { ids.append(vocab[eotToken] ?? 0) }

        return ids.map { Int32($0) }
    }

    /// Split text into initial tokens, keeping special tokens like [ko], [SPACE] intact.
    private func splitWithSpecials(_ text: String) -> [String] {
        // Match special tokens [XXX] or individual characters
        let pattern = "\\[[^\\]]+\\]|."
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text.map { String($0) }
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}

// MARK: - Punctuation Normalization

func puncNorm(_ text: String) -> String {
    var t = text
    if t.isEmpty { return "." }
    // Capitalize first letter
    if let first = t.first, first.isLowercase {
        t = first.uppercased() + t.dropFirst()
    }
    // Multiple spaces → single
    t = t.components(separatedBy: .whitespaces)
          .filter { !$0.isEmpty }
          .joined(separator: " ")
    // Common replacements
    let replacements: [(String, String)] = [
        ("...", ", "), ("…", ", "), (":", ","), (" - ", ", "),
        (";", ", "), ("—", "-"), ("–", "-"), (" ,", ",")
    ]
    for (old, new) in replacements {
        t = t.replacingOccurrences(of: old, with: new)
    }
    t = t.trimmingCharacters(in: .whitespaces)
    let enders: Set<Character> = [".", "!", "?", "-", ","]
    if !enders.contains(t.last ?? ".") {
        t += "."
    }
    return t
}

// MARK: - WAV Writer

/// Write a 32-bit float array as a 16-bit PCM WAV file.
func writeWAV(samples: [Float], sampleRate: Int, to url: URL) throws {
    let numSamples = samples.count
    let numChannels: Int = 1
    let bitsPerSample: Int = 16
    let byteRate = sampleRate * numChannels * bitsPerSample / 8
    let blockAlign = numChannels * bitsPerSample / 8
    let dataSize = numSamples * blockAlign
    let fileSize = 36 + dataSize

    var data = Data(capacity: fileSize + 8)

    func append(_ str: String) { data.append(contentsOf: str.utf8) }
    func appendU32(_ v: UInt32) {
        var x = v.littleEndian; data.append(contentsOf: withUnsafeBytes(of: &x, Array.init))
    }
    func appendU16(_ v: UInt16) {
        var x = v.littleEndian; data.append(contentsOf: withUnsafeBytes(of: &x, Array.init))
    }

    // RIFF header
    append("RIFF")
    appendU32(UInt32(fileSize))
    append("WAVE")

    // fmt chunk
    append("fmt ")
    appendU32(16)
    appendU16(1)  // PCM
    appendU16(UInt16(numChannels))
    appendU32(UInt32(sampleRate))
    appendU32(UInt32(byteRate))
    appendU16(UInt16(blockAlign))
    appendU16(UInt16(bitsPerSample))

    // data chunk
    append("data")
    appendU32(UInt32(dataSize))

    // Samples — clamp to [-1,1] and convert to Int16
    for s in samples {
        let clamped = max(-1.0, min(1.0, s))
        let pcm = Int16(clamped * 32767.0)
        appendU16(UInt16(bitPattern: pcm))
    }

    try data.write(to: url)
}

// MARK: - Chatterbox Pipeline

/// Orchestrates the full Chatterbox TTS inference in Swift/MLX-Swift.
final class ChatterboxPipeline {
    let voiceEncoder: VoiceEncoder
    let t3Model: T3Model
    let hiftGen: HiFTGenerator
    let tokenizer: KoreanBPETokenizer

    // MARK: Init

    init() throws {
        // 1. Load tokenizer
        tokenizer = try KoreanBPETokenizer(tokenizerJSONURL: ModelPaths.tokenizerJSON)

        // 2. Create model instances
        voiceEncoder = VoiceEncoder()
        t3Model      = T3Model()
        hiftGen      = HiFTGenerator()

        // 3. Load weights from safetensors
        print("[Pipeline] Loading weights from safetensors...")
        let t0 = Date()
        let allWeights = try loadWeights(from: ModelPaths.chatterboxModel)
        print(String(format: "[Pipeline] Loaded \(allWeights.count) tensors in %.1fs",
                     Date().timeIntervalSince(t0)))

        // 4. Distribute weights to each model
        loadIntoModel(voiceEncoder, prefix: "ve.", from: allWeights)
        loadIntoModel(t3Model,      prefix: "t3.", from: allWeights)
        loadIntoModel(hiftGen,      prefix: "s3gen.mel2wav.", from: allWeights)

        MLX.eval(voiceEncoder.parameters(), t3Model.parameters(), hiftGen.parameters())
        print("[Pipeline] Weights loaded and evaluated.")
    }

    private func loadIntoModel(_ model: Module, prefix: String, from weights: [String: MLXArray]) {
        let filtered = filterWeights(weights, prefix: prefix)
        let nested = ModuleParameters.unflattened(filtered)
        model.update(parameters: nested)
    }

    // MARK: Generate

    /// Full TTS generation.
    /// - Parameters:
    ///   - text: Korean text to synthesize
    ///   - referenceWAV: reference audio samples at 16kHz (for voice cloning)
    ///   - exaggeration: emotion exaggeration (default 0.5)
    ///   - cfgWeight: classifier-free guidance (default 0.5)
    ///   - temperature: sampling temperature (default 0.8)
    /// - Returns: audio samples (Float) at 24kHz
    func generate(
        text: String,
        referenceWAV: MLXArray,          // (N,) float32 at 16kHz
        exaggeration: Float = 0.5,
        cfgWeight: Float = 0.5,
        temperature: Float = 0.8
    ) -> [Float] {
        let t0 = Date()

        // ── Step 1: Speaker embedding ──────────────────────────────────────────
        print("[Pipeline] Computing speaker embedding...")
        let speakerEmb = voiceEncoder.embed(wav: referenceWAV)  // (256,)
        MLX.eval(speakerEmb)
        let speakerEmbBatched = speakerEmb.expandedDimensions(axis: 0)  // (1, 256)
        print(String(format: "[Pipeline] Speaker emb done in %.2fs", Date().timeIntervalSince(t0)))

        // ── Step 2: Tokenize text ──────────────────────────────────────────────
        let normalized = puncNorm(text)
        let tokenIds = tokenizer.encode(normalized, addSOT: true, addEOT: true)
        let textTokens = MLXArray(tokenIds).reshaped([1, tokenIds.count])  // (1, T_text)
        print("[Pipeline] Text tokens: \(tokenIds)")

        // ── Step 3: T3 inference ───────────────────────────────────────────────
        print("[Pipeline] Running T3 (text → speech tokens)...")
        let t1 = Date()
        let emotionAdv = MLXArray(exaggeration).reshaped([1, 1, 1])
        let cond = T3Cond(
            speakerEmb: speakerEmbBatched,
            emotionAdv: emotionAdv,
            condPromptSpeechEmb: nil
        )

        let speechTokens = t3Model.inference(
            t3Cond: cond,
            textTokens: textTokens,
            maxNewTokens: 1000,
            temperature: temperature,
            cfgWeight: cfgWeight,
            repetitionPenalty: 1.2
        )
        MLX.eval(speechTokens)
        let numTokens = speechTokens.shape[1]
        print(String(format: "[Pipeline] T3 generated \(numTokens) speech tokens in %.2fs",
                     Date().timeIntervalSince(t1)))

        // ── Step 4: HiFTGenerator (speech tokens → mel → audio) ───────────────
        // Note: In the full pipeline, S3Gen decodes speech tokens to mel first.
        // For this spike, we use a placeholder mel derived from the reference audio
        // to validate the mel→audio path. Full S3Gen will be added in next phase.
        print("[Pipeline] Running HiFTGenerator (mel → audio)...")
        let t2 = Date()

        // Compute mel from reference audio (resampled to 24kHz equivalent)
        // For spike: use the reference audio mel as a proxy
        let refMel = s3genMelSpectrogram(wav: referenceWAV)  // (T, 80)
        let refMelBatched = refMel.expandedDimensions(axis: 0)  // (1, T, 80)

        let audioOut = hiftGen(refMelBatched)  // (audio_samples,)
        MLX.eval(audioOut)
        print(String(format: "[Pipeline] HiFTGenerator done in %.2fs", Date().timeIntervalSince(t2)))

        let elapsed = Date().timeIntervalSince(t0)
        print(String(format: "[Pipeline] Total time: %.2fs", elapsed))

        // Convert to [Float]
        return audioOut.asArray(Float.self)
    }
}

// MARK: - Audio File Loading (16kHz)

/// Load a 16kHz mono WAV file into an MLXArray of float32 samples.
/// This is a minimal WAV parser that handles 16-bit PCM.
func loadWAV(url: URL) throws -> (samples: MLXArray, sampleRate: Int) {
    let data = try Data(contentsOf: url)

    guard data.count > 44 else {
        throw NSError(domain: "WAV", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "File too small"])
    }

    // Parse RIFF header
    func readU32(_ offset: Int) -> UInt32 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
    func readU16(_ offset: Int) -> UInt16 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }

    let audioFormat  = Int(readU16(20))  // 1 = PCM
    let numChannels  = Int(readU16(22))
    let sampleRate   = Int(readU32(24))
    let bitsPerSample = Int(readU16(34))

    guard audioFormat == 1 else {
        throw NSError(domain: "WAV", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Only PCM WAV supported"])
    }

    // Find data chunk
    var offset = 36
    while offset + 8 <= data.count {
        let chunkID = String(bytes: data[offset..<(offset+4)], encoding: .ascii) ?? ""
        let chunkSize = Int(readU32(offset + 4))
        if chunkID == "data" {
            offset += 8
            let numSamples = chunkSize / (numChannels * bitsPerSample / 8)
            var samples = [Float]()
            samples.reserveCapacity(numSamples)

            for i in 0..<numSamples {
                let sampleOffset = offset + i * numChannels * (bitsPerSample / 8)
                // Take only channel 0 for mono
                if bitsPerSample == 16 {
                    let raw = Int16(bitPattern: readU16(sampleOffset))
                    samples.append(Float(raw) / 32768.0)
                } else if bitsPerSample == 32 {
                    let raw = data.withUnsafeBytes { ptr in
                        ptr.load(fromByteOffset: sampleOffset, as: Float.self)
                    }
                    samples.append(raw)
                }
            }
            return (MLXArray(samples), sampleRate)
        }
        offset += 8 + chunkSize
    }

    throw NSError(domain: "WAV", code: 3,
                  userInfo: [NSLocalizedDescriptionKey: "data chunk not found"])
}
