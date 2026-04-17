// T3Model.swift
// Chatterbox TTS — T3 speech-token generator
//
// Weight key hierarchy (after stripping global "t3." prefix):
//   speech_emb.weight                              (8194, 1024)
//   text_emb.weight                                (2454, 1024)
//   speech_head.weight                             (8194, 1024)
//   text_head.weight                               (2454, 1024)
//   speech_pos_emb.emb.weight                      (4100, 1024)
//   text_pos_emb.emb.weight                        (2050, 1024)
//   cond_enc.spkr_enc.weight                       …
//   tfmr.model.layers.N.self_attn.q_proj.weight    …  (Q4)
//   tfmr.model.norm.weight                         (1024,)

import MLX
import MLXNN
import MLXRandom
import Foundation

// MARK: - LearnedPositionEmbeddings

/// Wraps a single Embedding(maxLen, dim) and returns the first T positions.
/// Weight key: "<prefix>.emb"
final class LearnedPositionEmbeddings: Module, @unchecked Sendable {
    @ModuleInfo(key: "emb") var emb: Embedding

    nonisolated override init() { fatalError() }

    nonisolated init(maxLen: Int, dim: Int) {
        self._emb.wrappedValue = Embedding(embeddingCount: maxLen, dimensions: dim)
        super.init()
    }

    /// Returns position embeddings for the first T positions.
    /// - Parameter x: any (B, T) tensor — only the T dimension is used.
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let T = x.shape[1]
        let positions = MLXArray(Array(0..<T).map { Int32($0) })  // (T,)
        return emb(positions)  // (T, dim)
    }

    /// Returns the embedding for a single position index.
    func forPosition(_ pos: Int) -> MLXArray {
        let idx = MLXArray([Int32(pos)])
        return emb(idx)  // (1, dim)
    }
}

// MARK: - Temperature sampling

/// Sample a token index from `logits` (1D, already un-batched) using temperature.
private func sampleToken(logits: MLXArray, temperature: Float) -> Int {
    if temperature <= 0 {
        return logits.argMax(axis: -1).item(Int.self)
    }
    let scaled = logits / MLXArray(temperature)
    let probs = softmax(scaled, axis: -1)
    // Gumbel-max trick: argmax( log(p) + Gumbel(0,1) )
    // Gumbel sample = -log(-log(U)),  U ~ Uniform(1e-20, 1)
    let u = MLXRandom.uniform(low: Float(1e-20), high: Float(1.0), probs.shape)
    let gumbel = -log(-log(u))
    return (log(probs) + gumbel).argMax(axis: -1).item(Int.self)
}

// MARK: - Repetition penalty helper

/// Returns a copy of `logits` (shape [vocabSize]) with per-token repetition penalty applied.
private func applyRepetitionPenalty(
    logits: MLXArray,
    generatedTokens: [Int],
    penalty: Float
) -> MLXArray {
    guard penalty != 1.0, !generatedTokens.isEmpty else { return logits }
    // Build a factor array: 1.0 everywhere, `penalty` at generated positions.
    var factors = [Float](repeating: 1.0, count: logits.shape[0])
    for tid in generatedTokens {
        if tid >= 0 && tid < factors.count {
            factors[tid] = penalty
        }
    }
    let factorArr = MLXArray(factors)
    // For positive logits: divide by penalty (reduce probability).
    // For negative logits: multiply by penalty (push more negative).
    let positive = logits .>= MLXArray(Float(0))
    return MLX.which(positive, logits / factorArr, logits * factorArr)
}

// MARK: - T3Model

/// T3: text-to-speech-token transformer (LLaMA-520M backbone).
///
/// Inference method generates speech tokens from text tokens conditioned on
/// a speaker embedding, with optional classifier-free guidance.
final class T3Model: Module, @unchecked Sendable {
    // Embeddings
    @ModuleInfo(key: "text_emb")        var textEmb:       Embedding
    @ModuleInfo(key: "speech_emb")      var speechEmb:     Embedding
    @ModuleInfo(key: "text_pos_emb")    var textPosEmb:    LearnedPositionEmbeddings
    @ModuleInfo(key: "speech_pos_emb")  var speechPosEmb:  LearnedPositionEmbeddings

    // Heads
    @ModuleInfo(key: "text_head")       var textHead:      Linear
    @ModuleInfo(key: "speech_head")     var speechHead:    Linear

    // Conditioning encoder
    @ModuleInfo(key: "cond_enc")        var condEnc:       T3CondEnc

    // Transformer backbone
    @ModuleInfo(key: "tfmr")            var tfmr:          LlamaWrapper

    // Special tokens
    static let sotSpeech = T3Constants.sotSpeech  // 6561
    static let eotSpeech = T3Constants.eotSpeech  // 6562
    static let sotText   = T3Constants.sotText    // 255
    static let eotText   = T3Constants.eotText    // 0

    nonisolated override init() {
        let D = T3Constants.nChannels  // 1024

        self._textEmb.wrappedValue      = Embedding(embeddingCount: T3Constants.textTokensDictSize,   dimensions: D)
        self._speechEmb.wrappedValue    = Embedding(embeddingCount: T3Constants.speechTokensDictSize, dimensions: D)
        self._textPosEmb.wrappedValue   = LearnedPositionEmbeddings(maxLen: T3Constants.maxTextSeqLen,  dim: D)
        self._speechPosEmb.wrappedValue = LearnedPositionEmbeddings(maxLen: T3Constants.maxMelSeqLen,   dim: D)
        self._textHead.wrappedValue     = Linear(D, T3Constants.textTokensDictSize,   bias: false)
        self._speechHead.wrappedValue   = Linear(D, T3Constants.speechTokensDictSize, bias: false)
        self._condEnc.wrappedValue      = T3CondEnc()
        self._tfmr.wrappedValue         = LlamaWrapper()
        super.init()
    }

    // MARK: - Inference

    /// Generate speech tokens autoregressively from text tokens.
    ///
    /// - Parameters:
    ///   - t3Cond: speaker/emotion conditioning
    ///   - textTokens: (1, T_text) int32 text token ids (NOT batched for CFG yet)
    ///   - maxNewTokens: maximum speech tokens to generate
    ///   - temperature: sampling temperature (0 = greedy)
    ///   - cfgWeight: classifier-free guidance weight (0 = disabled)
    ///   - repetitionPenalty: penalty > 1.0 reduces repeated tokens
    /// - Returns: (1, T_speech) generated speech token ids (int32), SOT/EOT stripped
    func inference(
        t3Cond: T3Cond,
        textTokens: MLXArray,           // (1, T_text)
        maxNewTokens: Int = 1000,
        temperature: Float = 0.8,
        cfgWeight: Float = 0.5,
        repetitionPenalty: Float = 1.2
    ) -> MLXArray {
        let useCFG = cfgWeight > 0
        // B = 2 when CFG is active (conditioned + unconditioned), else 1
        let B = useCFG ? 2 : 1

        // ── 1. Conditioning embeddings ──────────────────────────────────────
        // condEmb: (1, condLen, 1024)
        let condEmb1 = condEnc(t3Cond)
        let condLen  = condEmb1.shape[1]
        // For CFG: duplicate along batch axis → (2, condLen, 1024)
        // Second item is the "null" conditioning (zeroed out below for text, kept for cond)
        let condEmb: MLXArray
        if useCFG {
            condEmb = concatenated([condEmb1, condEmb1], axis: 0)  // (2, condLen, 1024)
        } else {
            condEmb = condEmb1
        }

        // ── 2. Text embeddings ───────────────────────────────────────────────
        // textTokens is (1, T_text); expand to (B, T_text) by repeating
        let textTokensB: MLXArray
        if useCFG {
            textTokensB = concatenated([textTokens, textTokens], axis: 0)  // (2, T_text)
        } else {
            textTokensB = textTokens  // (1, T_text)
        }
        let T_text = textTokens.shape[1]

        // Token embeddings + position embeddings
        // textEmb(textTokensB) → (B, T_text, 1024)
        // textPosEmb(textTokens) → (T_text, 1024) → broadcast over B
        var textEmbs = textEmb(textTokensB)                           // (B, T_text, 1024)
        let textPos  = textPosEmb(textTokens).reshaped([1, T_text, T3Constants.nChannels])  // (1, T_text, 1024)
        textEmbs = textEmbs + textPos                                  // broadcast (B, T_text, 1024)

        // For CFG: zero out the second item's text embeddings (null text conditioning)
        if useCFG {
            let zeroText = MLXArray.zeros([1, T_text, T3Constants.nChannels])
            textEmbs = concatenated([textEmbs[0..<1], zeroText], axis: 0)
        }

        // ── 3. BOS speech token ──────────────────────────────────────────────
        let sotId = MLXArray([Int32(T3Model.sotSpeech)]).reshaped([1, 1])  // (1, 1)
        // speechEmb → (1, 1, 1024), speechPosEmb at position 0 → (1, 1024)
        let bosEmbed = speechEmb(sotId) + speechPosEmb.forPosition(0).reshaped([1, 1, T3Constants.nChannels])
        // (1, 1, 1024)
        let bosEmbedB: MLXArray
        if useCFG {
            bosEmbedB = concatenated([bosEmbed, bosEmbed], axis: 0)  // (2, 1, 1024)
        } else {
            bosEmbedB = bosEmbed
        }

        // ── 4. Initial prefill input ─────────────────────────────────────────
        // Concatenate along time axis: [condEmb | textEmbs | bosEmbed]
        let initialInput = concatenated([condEmb, textEmbs, bosEmbedB], axis: 1)
        // Shape: (B, condLen + T_text + 1, 1024)

        // ── 5. KV caches — one per transformer layer ─────────────────────────
        var caches = [KVCache](repeating: KVCache(), count: LlamaConfig.numHiddenLayers)

        // ── 6. Prefill ───────────────────────────────────────────────────────
        var hidden = tfmr(inputEmbeddings: initialInput, caches: &caches)
        // hidden: (B, prefill_len, 1024)

        // ── 7. Autoregressive generation loop ────────────────────────────────
        var generatedTokenIds = [Int]()
        // Track current speech position (0 was the BOS, so next is 1)
        var speechPos = 1

        for _ in 0..<maxNewTokens {
            // Logits from last position: speechHead( hidden[:, -1, :] )
            // hidden[:, -1, :] → (B, 1024)
            let lastHidden = hidden[0..., -1, 0...]  // (B, 1024)
            var logits = speechHead(lastHidden)       // (B, speechVocabSize)

            // Apply CFG: guided_logits = cond + cfgWeight * (cond - uncond)
            let singleLogits: MLXArray
            if useCFG {
                let condLogits   = logits[0]  // (speechVocabSize,)
                let uncondLogits = logits[1]  // (speechVocabSize,)
                singleLogits = condLogits + MLXArray(cfgWeight) * (condLogits - uncondLogits)
            } else {
                singleLogits = logits[0]  // (speechVocabSize,)
            }

            // Apply repetition penalty
            let penalisedLogits = applyRepetitionPenalty(
                logits: singleLogits,
                generatedTokens: generatedTokenIds,
                penalty: repetitionPenalty
            )

            // Sample next token
            MLX.eval(penalisedLogits)
            let nextToken = sampleToken(logits: penalisedLogits, temperature: temperature)

            // Stop on EOT
            if nextToken == T3Model.eotSpeech {
                break
            }

            generatedTokenIds.append(nextToken)

            // Prepare next-step embedding
            let tokenId = MLXArray([Int32(nextToken)]).reshaped([1, 1])  // (1, 1)
            let nextEmbed = speechEmb(tokenId) + speechPosEmb.forPosition(speechPos).reshaped([1, 1, T3Constants.nChannels])
            // (1, 1, 1024)
            speechPos += 1

            let nextEmbedB: MLXArray
            if useCFG {
                nextEmbedB = concatenated([nextEmbed, nextEmbed], axis: 0)  // (2, 1, 1024)
            } else {
                nextEmbedB = nextEmbed
            }

            hidden = tfmr(inputEmbeddings: nextEmbedB, caches: &caches)
            // hidden: (B, 1, 1024)
        }

        // ── 8. Return generated token ids ────────────────────────────────────
        if generatedTokenIds.isEmpty {
            return MLXArray.zeros([1, 0], dtype: .int32)
        }
        let tokenArr = MLXArray(generatedTokenIds.map { Int32($0) })  // (T_speech,)
        return tokenArr.reshaped([1, generatedTokenIds.count])         // (1, T_speech)
    }
}
