// T3CondEnc.swift
// Chatterbox TTS — T3 Conditioning Encoder
// Maps speaker embedding + emotion adversarial scalar + optional speech prompt
// → conditioning sequence fed to the LLaMA backbone.
//
// Weight key hierarchy (after "t3." prefix stripped):
//   cond_enc.spkr_enc.{weight, bias}
//   cond_enc.emotion_adv_fc.weight
//   cond_enc.perceiver.pre_attention_query
//   cond_enc.perceiver.attn.{to_q, to_k, to_v, proj_out}.{weight, bias}
//   cond_enc.perceiver.attn.norm.{weight, bias}

import MLX
import MLXNN
import MLXRandom
import Foundation

// MARK: - T3Cond

/// Input bundle for the conditioning encoder.
struct T3Cond {
    /// Speaker embedding (B, 256)
    var speakerEmb: MLXArray
    /// Emotion adversarial scalar — broadcast-compatible with (B, 1, 1)
    var emotionAdv: MLXArray
    /// Optional: pre-processed speech prompt embeddings (B, T_prompt, 1024).
    /// When present the Perceiver cross-attends over this and returns (B, 32, 1024).
    var condPromptSpeechEmb: MLXArray?
}

// MARK: - PerceiverAttentionBlock
// Key: "attn"  (inside Perceiver)

/// Perceiver cross-attention block.
/// Latents (learned queries) attend to [input_context ; latents] for keys/values.
final class PerceiverAttentionBlock: Module, @unchecked Sendable {
    @ModuleInfo(key: "norm")     var norm:    LayerNorm
    @ModuleInfo(key: "to_q")     var toQ:     Linear
    @ModuleInfo(key: "to_k")     var toK:     Linear
    @ModuleInfo(key: "to_v")     var toV:     Linear
    @ModuleInfo(key: "proj_out") var projOut: Linear

    let nHeads: Int
    let headDim: Int
    let scale: Float

    // dim=1024, nHeads=8, headDim=128
    nonisolated override init() { fatalError() }

    nonisolated init(dim: Int = T3Constants.nChannels, nHeads: Int = 8) {
        self.nHeads  = nHeads
        self.headDim = dim / nHeads
        self.scale   = 1.0 / sqrt(Float(dim / nHeads))

        self._norm.wrappedValue    = LayerNorm(dimensions: dim)
        self._toQ.wrappedValue     = Linear(dim, dim)
        self._toK.wrappedValue     = Linear(dim, dim)
        self._toV.wrappedValue     = Linear(dim, dim)
        self._projOut.wrappedValue = Linear(dim, dim)
        super.init()
    }

    /// - Parameters:
    ///   - x:       Context sequence (B, T_ctx, dim) — the speech prompt embeddings.
    ///   - latents: Query latents (B, T_latent, dim) — the learned queries broadcast to batch.
    /// - Returns:   Updated latents (B, T_latent, dim), with residual added.
    func callAsFunction(_ x: MLXArray, latents: MLXArray) -> MLXArray {
        let B        = latents.shape[0]
        let T_latent = latents.shape[1]
        let T_ctx    = x.shape[1]
        let dim      = latents.shape[2]

        // Shared norm applied to both context and latents
        let normedX       = norm(x)
        let normedLatents = norm(latents)

        // Keys and values attend over [context ; latents]
        let kv = concatenated([normedX, normedLatents], axis: 1)  // (B, T_ctx+T_latent, dim)

        // Project
        let q = toQ(normedLatents)  // (B, T_latent, dim)
        let k = toK(kv)             // (B, T_ctx+T_latent, dim)
        let v = toV(kv)             // (B, T_ctx+T_latent, dim)

        let T_kv = T_ctx + T_latent

        // Reshape to multi-head form
        let qH = q.reshaped([B, T_latent, nHeads, headDim]).transposed(0, 2, 1, 3)  // (B, nH, T_latent, headDim)
        let kH = k.reshaped([B, T_kv,     nHeads, headDim]).transposed(0, 2, 1, 3)  // (B, nH, T_kv,     headDim)
        let vH = v.reshaped([B, T_kv,     nHeads, headDim]).transposed(0, 2, 1, 3)  // (B, nH, T_kv,     headDim)

        // Scaled dot-product attention (no causal mask — cross-attention over full context)
        let attnW = softmax(matmul(qH, kH.transposed(0, 1, 3, 2)) * MLXArray(scale), axis: -1)
        // (B, nH, T_latent, headDim)
        var attnOut = matmul(attnW, vH)

        // Merge heads: (B, T_latent, dim)
        attnOut = attnOut.transposed(0, 2, 1, 3).reshaped([B, T_latent, dim])

        // Output projection + residual connection
        return projOut(attnOut) + latents
    }
}

// MARK: - Perceiver
// Key: "perceiver"  (inside T3CondEnc)

/// Wraps PerceiverAttentionBlock and the learned query tensor.
final class Perceiver: Module, @unchecked Sendable {
    @ModuleInfo(key: "attn")                 var attn:          PerceiverAttentionBlock
    @ParameterInfo(key: "pre_attention_query") var preAttnQuery: MLXArray

    nonisolated override init() { fatalError() }

    nonisolated init(
        queryLen: Int = T3Constants.perceiverQueryLen,
        dim: Int      = T3Constants.nChannels
    ) {
        self._attn.wrappedValue          = PerceiverAttentionBlock(dim: dim)
        self._preAttnQuery.wrappedValue  = MLXRandom.normal([1, queryLen, dim])
        super.init()
    }

    /// - Parameter x: Speech prompt embeddings (B, T_ctx, dim)
    /// - Returns: Condensed conditioning (B, queryLen, dim)
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let B = x.shape[0]
        // Broadcast learned queries to batch
        let queries = broadcast(preAttnQuery, to: [B, preAttnQuery.shape[1], preAttnQuery.shape[2]])
        return attn(x, latents: queries)
    }
}

// MARK: - T3CondEnc
// Key: "cond_enc"  (inside T3Model)

/// Conditioning encoder for T3.
///
/// Produces a conditioning sequence of shape:
///   - (B, 2,  1024)  — when no speech prompt provided  [spkr | emotion]
///   - (B, 34, 1024)  — when speech prompt provided     [spkr | perceiver(32) | emotion]
///
/// Matches Python cond_enc.py concatenation order:
///   cond_spkr | cond_clap(omitted) | cond_prompt_speech | cond_emotion_adv
final class T3CondEnc: Module, @unchecked Sendable {
    @ModuleInfo(key: "spkr_enc")      var spkrEnc:     Linear
    @ModuleInfo(key: "emotion_adv_fc") var emotionAdvFc: Linear
    @ModuleInfo(key: "perceiver")     var perceiver:   Perceiver

    nonisolated override init() { fatalError() }

    nonisolated init(
        speakerEmbSize: Int = T3Constants.speakerEmbedSize,
        dim: Int            = T3Constants.nChannels
    ) {
        // spkr_enc: (256 → 1024) with bias
        self._spkrEnc.wrappedValue      = Linear(speakerEmbSize, dim)
        // emotion_adv_fc: (1 → 1024) no bias
        self._emotionAdvFc.wrappedValue = Linear(1, dim, bias: false)
        self._perceiver.wrappedValue    = Perceiver(dim: dim)
        super.init()
    }

    /// - Parameter cond: T3Cond bundle
    /// - Returns: Conditioning sequence (B, 2+[32], 1024)
    func callAsFunction(_ cond: T3Cond) -> MLXArray {
        let B = cond.speakerEmb.shape[0]

        // 1. Speaker: (B, 256) → (B, 1024) → (B, 1, 1024)
        let spkrCond = spkrEnc(cond.speakerEmb).expandedDimensions(axis: 1)

        // 2. Emotion: broadcast to (B, 1, 1), project → (B, 1, 1024)
        //    emotionAdv may come in as a scalar, (1,), (B,), or already (B, 1, 1)
        let emoShaped: MLXArray
        let emoRaw = cond.emotionAdv
        switch emoRaw.shape.count {
        case 0:
            // scalar → (B, 1, 1)
            emoShaped = broadcast(emoRaw.reshaped([1, 1, 1]), to: [B, 1, 1])
        case 1:
            // (B,) or (1,) → (B, 1, 1)
            let b = emoRaw.shape[0]
            let t = emoRaw.reshaped([b, 1, 1])
            emoShaped = b == 1 ? broadcast(t, to: [B, 1, 1]) : t
        case 2:
            // (B, 1) → (B, 1, 1)
            emoShaped = emoRaw.expandedDimensions(axis: 2)
        default:
            emoShaped = emoRaw
        }
        // emotionAdvFc expects last dim = 1; input is (B, 1, 1) → (B, 1, 1024)
        let emotionCond = emotionAdvFc(emoShaped)

        // 3. Speech prompt through Perceiver (optional)
        var parts: [MLXArray] = [spkrCond]
        if let speechEmb = cond.condPromptSpeechEmb {
            // speechEmb: (B, T_prompt, 1024) → perceiver → (B, 32, 1024)
            let percOut = perceiver(speechEmb)
            parts.append(percOut)
        }
        parts.append(emotionCond)

        // 4. Concatenate along sequence axis
        return concatenated(parts, axis: 1)
    }
}
