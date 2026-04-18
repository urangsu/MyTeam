// LlamaModel.swift
// Chatterbox TTS — LLaMA-520M backbone with Q4 quantization
// Weight key hierarchy (after global "t3." strip):
//   tfmr.model.layers.N.self_attn.q_proj.{weight,scales,biases}
//   tfmr.model.layers.N.input_layernorm.weight
//   tfmr.model.norm.weight
//   tfmr.model.embed_tokens.weight

import MLX
import MLXNN
import MLXRandom
import Foundation

// MARK: - Q4Linear

/// Stores 4-bit quantised weights and dequantises on each forward pass.

@InferenceActor final class Q4Linear: Module, @unchecked Sendable {
    @ParameterInfo(key: "weight") var weight: MLXArray
    @ParameterInfo(key: "scales") var scales: MLXArray
    @ParameterInfo(key: "biases") var biases: MLXArray
    // Optional dense bias (key "bias", separate from quantisation biases)
    var layerBias: MLXArray?

    let inputSize: Int
    let outputSize: Int

    nonisolated override init() { fatalError() }

    init(inputSize: Int, outputSize: Int, hasBias: Bool = false) {
        self.inputSize = inputSize
        self.outputSize = outputSize
        
        super.init()
        
        // Packed Q4: each int stores 2 × 4-bit values → width = inputSize / (32/4) = inputSize / 8
        let packedWidth = inputSize / 8
        let numGroups  = inputSize / LlamaConfig.quantGroupSize
        
        self._weight.wrappedValue = zeros([outputSize, packedWidth], dtype: .uint32)
        self._scales.wrappedValue = zeros([outputSize, numGroups])
        self._biases.wrappedValue = zeros([outputSize, numGroups])
        if hasBias {
            self.layerBias = zeros([outputSize])
        }
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let w = dequantized(
            weight,
            scales: scales,
            biases: biases,
            groupSize: LlamaConfig.quantGroupSize,
            bits: LlamaConfig.quantBits
        )
        if let b = layerBias {
            return addMM(b, x, w.T)
        }
        return matmul(x, w.T)
    }
}

// MARK: - KVCache

/// Accumulates key / value tensors across decode steps for one layer.
struct KVCache: @unchecked Sendable {
    /// (B, nHeads, T_past, headDim)
    var keys: MLXArray?
    /// (B, nHeads, T_past, headDim)
    var values: MLXArray?

    var seqLen: Int { keys?.shape[2] ?? 0 }

    /// Appends `newKeys` / `newValues` along the time axis (axis 2).
    mutating func update(newKeys: MLXArray, newValues: MLXArray) {
        if let k = keys, let v = values {
            keys   = concatenated([k, newKeys],   axis: 2)
            values = concatenated([v, newValues], axis: 2)
        } else {
            keys   = newKeys
            values = newValues
        }
    }
}

// MARK: - LlamaRoPE

/// Rotary position embeddings with LLaMA-3 long-context scaling.
final class LlamaRoPE: @unchecked Sendable {
    let headDim: Int
    let ropeTheta: Float
    let scalingFactor: Float
    let highFreqFactor: Float
    let lowFreqFactor: Float
    let origMaxLen: Int

    init(
        headDim: Int      = LlamaConfig.headDim,
        ropeTheta: Float  = LlamaConfig.ropeTheta,
        scalingFactor: Float   = LlamaConfig.ropeScalingFactor,
        highFreqFactor: Float  = LlamaConfig.ropeHighFreqFactor,
        lowFreqFactor: Float   = LlamaConfig.ropeLowFreqFactor,
        origMaxLen: Int        = LlamaConfig.ropeOrigMaxLen
    ) {
        self.headDim       = headDim
        self.ropeTheta     = ropeTheta
        self.scalingFactor = scalingFactor
        self.highFreqFactor = highFreqFactor
        self.lowFreqFactor  = lowFreqFactor
        self.origMaxLen     = origMaxLen
    }

    /// LLaMA-3 scaled inverse frequencies for a single head-dim position.
    private func scaledFreqs() -> MLXArray {
        let half = headDim / 2
        // Base frequencies: theta^(-2i/d)
        let i = MLXArray(Array(0..<half).map { Float($0) })
        let baseFreqs = 1.0 / pow(MLXArray(ropeTheta), i * (2.0 / Float(headDim)))

        // LLaMA-3 wavelength-based scaling
        let lowFreqWavelen  = Float(origMaxLen) / lowFreqFactor
        let highFreqWavelen = Float(origMaxLen) / highFreqFactor

        let twoPi = Float.pi * 2.0
        let wavelen = twoPi / baseFreqs  // element-wise

        // Smooth blend factor for mid-range frequencies
        let smooth = (MLXArray(Float(origMaxLen)) / wavelen - MLXArray(lowFreqFactor))
                   / (MLXArray(highFreqFactor) - MLXArray(lowFreqFactor))
        let smoothedFreqs = (1.0 - smooth) * baseFreqs / scalingFactor + smooth * baseFreqs

        // Select regime per frequency
        let scaled = MLX.which(
            wavelen .> MLXArray(lowFreqWavelen),      // long wavelength → scale down
            baseFreqs / MLXArray(scalingFactor),
            MLX.which(
                wavelen .< MLXArray(highFreqWavelen), // short wavelength → keep
                baseFreqs,
                smoothedFreqs                          // mid → smooth blend
            )
        )
        return scaled
    }

    /// Apply RoPE to `x` of shape (B, T, nHeads, headDim).
    /// `offset` is the position index of the first token in `x` (for decode mode).
    func apply(_ x: MLXArray, offset: Int = 0) -> MLXArray {
        let T = x.shape[1]
        let freqs = scaledFreqs()  // (headDim/2,)

        // Position indices: (T,)
        let positions = MLXArray(Array(offset..<(offset + T)).map { Float($0) })
        // Outer product: (T, headDim/2)
        let angles = positions[.ellipsis, .newAxis] * freqs[.newAxis, .ellipsis]
        // cos/sin: (1, T, 1, headDim/2)
        let cosA = MLX.cos(angles).reshaped([1, T, 1, headDim / 2])
        let sinA = MLX.sin(angles).reshaped([1, T, 1, headDim / 2])

        // Split x into two halves along last axis
        let parts = split(x, parts: 2, axis: -1)
        let x1 = parts[0]  // (B, T, nHeads, headDim/2)
        let x2 = parts[1]

        // Rotate: (x1, x2) → (x1*cos - x2*sin, x2*cos + x1*sin)
        let rotated1 = x1 * cosA - x2 * sinA
        let rotated2 = x2 * cosA + x1 * sinA

        return concatenated([rotated1, rotated2], axis: -1)
    }
}

// MARK: - LlamaAttention

/// Multi-head self-attention with Q4-quantised projections and KV-cache support.

@InferenceActor final class LlamaAttention: Module, @unchecked Sendable {
    @ModuleInfo(key: "q_proj") var qProj: Q4Linear
    @ModuleInfo(key: "k_proj") var kProj: Q4Linear
    @ModuleInfo(key: "v_proj") var vProj: Q4Linear
    @ModuleInfo(key: "o_proj") var oProj: Q4Linear

    let nHeads: Int
    let nKVHeads: Int
    let headDim: Int
    let scale: Float
    let rope: LlamaRoPE

    nonisolated override init() { fatalError("Use designated init") }

    init(
        hiddenSize: Int  = LlamaConfig.hiddenSize,
        nHeads: Int      = LlamaConfig.numAttentionHeads,
        nKVHeads: Int    = LlamaConfig.numKeyValueHeads,
        headDim: Int     = LlamaConfig.headDim
    ) {
        self.nHeads   = nHeads
        self.nKVHeads = nKVHeads
        self.headDim  = headDim
        self.scale    = 1.0 / sqrt(Float(headDim))
        self.rope     = LlamaRoPE()

        let kvDim = nKVHeads * headDim
        self._qProj.wrappedValue = Q4Linear(inputSize: hiddenSize, outputSize: nHeads * headDim)
        self._kProj.wrappedValue = Q4Linear(inputSize: hiddenSize, outputSize: kvDim)
        self._vProj.wrappedValue = Q4Linear(inputSize: hiddenSize, outputSize: kvDim)
        self._oProj.wrappedValue = Q4Linear(inputSize: nHeads * headDim, outputSize: hiddenSize)
        super.init()
    }

    func callAsFunction(
        _ x: MLXArray,
        mask: MLXArray? = nil,
        cache: inout KVCache
    ) -> MLXArray {
        let B = x.shape[0]
        let T = x.shape[1]
        let offset = cache.seqLen

        // Project
        var q = qProj(x)  // (B, T, nHeads*headDim)
        var k = kProj(x)  // (B, T, nKVHeads*headDim)
        var v = vProj(x)  // (B, T, nKVHeads*headDim)

        // Reshape to (B, T, nHeads, headDim)
        q = q.reshaped([B, T, nHeads,   headDim])
        k = k.reshaped([B, T, nKVHeads, headDim])
        v = v.reshaped([B, T, nKVHeads, headDim])

        // Apply RoPE
        q = rope.apply(q, offset: offset)
        k = rope.apply(k, offset: offset)

        // Transpose to (B, nHeads, T, headDim) for attention
        q = q.transposed(0, 2, 1, 3)
        k = k.transposed(0, 2, 1, 3)
        v = v.transposed(0, 2, 1, 3)

        // Update KV cache and retrieve full cached K, V
        cache.update(newKeys: k, newValues: v)
        let fullK = cache.keys!   // (B, nKVHeads, T_total, headDim)
        let fullV = cache.values! // (B, nKVHeads, T_total, headDim)

        // Repeat KV heads if nKVHeads < nHeads (GQA) — here nKVHeads == nHeads so this is a no-op
        let kExp: MLXArray
        let vExp: MLXArray
        if nKVHeads == nHeads {
            kExp = fullK
            vExp = fullV
        } else {
            let repeats = nHeads / nKVHeads
            kExp = concatenated(Array(repeating: fullK, count: repeats), axis: 1)
            vExp = concatenated(Array(repeating: fullV, count: repeats), axis: 1)
        }

        // Scaled dot-product attention: (B, nHeads, T, T_total)
        var attnWeights = matmul(q, kExp.transposed(0, 1, 3, 2)) * MLXArray(scale)

        // Additive causal mask (only needed during prefill when T > 1)
        if let m = mask {
            attnWeights = attnWeights + m
        }

        attnWeights = softmax(attnWeights, axis: -1)

        // Weighted sum of values: (B, nHeads, T, headDim)
        var attnOut = matmul(attnWeights, vExp)

        // Transpose back and reshape to (B, T, hiddenSize)
        attnOut = attnOut.transposed(0, 2, 1, 3).reshaped([B, T, nHeads * headDim])

        return oProj(attnOut)
    }
}

// MARK: - LlamaMLP

/// SwiGLU feed-forward with Q4-quantised gate / up / down projections.

@InferenceActor final class LlamaMLP: Module, @unchecked Sendable {
    @ModuleInfo(key: "gate_proj") var gateProj: Q4Linear
    @ModuleInfo(key: "up_proj")   var upProj:   Q4Linear
    @ModuleInfo(key: "down_proj") var downProj: Q4Linear

    nonisolated override init() { fatalError("Use designated init") }

    init(
        hiddenSize: Int       = LlamaConfig.hiddenSize,
        intermediateSize: Int = LlamaConfig.intermediateSize
    ) {
        self._gateProj.wrappedValue = Q4Linear(inputSize: hiddenSize, outputSize: intermediateSize)
        self._upProj.wrappedValue   = Q4Linear(inputSize: hiddenSize, outputSize: intermediateSize)
        self._downProj.wrappedValue = Q4Linear(inputSize: intermediateSize, outputSize: hiddenSize)
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let gate = silu(gateProj(x))
        let up   = upProj(x)
        return downProj(gate * up)
    }
}

// MARK: - LlamaDecoderLayer

/// One LLaMA transformer block: pre-norm → attention → residual → pre-norm → MLP → residual.

@InferenceActor final class LlamaDecoderLayer: Module, @unchecked Sendable {
    @ModuleInfo(key: "input_layernorm")         var inputNorm:  RMSNorm
    @ModuleInfo(key: "self_attn")               var selfAttn:   LlamaAttention
    @ModuleInfo(key: "post_attention_layernorm") var postNorm:   RMSNorm
    @ModuleInfo(key: "mlp")                     var mlp:        LlamaMLP
    
    let layerIdx: Int

    nonisolated init(layerIdx: Int) {
        self.layerIdx = layerIdx
        super.init()
        self._inputNorm.wrappedValue = RMSNorm(dimensions: LlamaConfig.hiddenSize, eps: LlamaConfig.rmsNormEps)
        self._selfAttn.wrappedValue  = LlamaAttention()
        self._postNorm.wrappedValue  = RMSNorm(dimensions: LlamaConfig.hiddenSize, eps: LlamaConfig.rmsNormEps)
        self._mlp.wrappedValue       = LlamaMLP()
    }

    nonisolated override init() {
        self.layerIdx = 0
        super.init()
        self._inputNorm.wrappedValue = RMSNorm(dimensions: LlamaConfig.hiddenSize, eps: LlamaConfig.rmsNormEps)
        self._selfAttn.wrappedValue  = LlamaAttention()
        self._postNorm.wrappedValue  = RMSNorm(dimensions: LlamaConfig.hiddenSize, eps: LlamaConfig.rmsNormEps)
        self._mlp.wrappedValue       = LlamaMLP()
    }

    func callAsFunction(
        _ x: MLXArray,
        mask: MLXArray? = nil,
        cache: inout KVCache
    ) -> MLXArray {
        var h = x
        // Self-attention sub-layer
        h = h + selfAttn(inputNorm(h), mask: mask, cache: &cache)
        // MLP sub-layer
        h = h + mlp(postNorm(h))
        return h
    }
}

// MARK: - LlamaInternals
// Key: "model"  (inside LlamaWrapper)
// Full path: t3.tfmr.model.*


@InferenceActor final class LlamaInternals: Module, @unchecked Sendable {
    @ModuleInfo(key: "embed_tokens") var embedTokens: Embedding
    @ModuleInfo(key: "layers")       var layers: [LlamaDecoderLayer]
    @ModuleInfo(key: "norm")         var norm: RMSNorm

    nonisolated override init() { fatalError() }

    nonisolated init(numLayers: Int = LlamaConfig.numHiddenLayers) {
        super.init()
        // embed_tokens is loaded from weights but not used in T3's forward pass
        // (T3 has its own text/speech embeddings)
        self._embedTokens.wrappedValue = Embedding(embeddingCount: 8, dimensions: LlamaConfig.hiddenSize)
        self._layers.wrappedValue = (0..<numLayers).map { i in LlamaDecoderLayer(layerIdx: i) }
        self._norm.wrappedValue   = RMSNorm(dimensions: LlamaConfig.hiddenSize, eps: LlamaConfig.rmsNormEps)
    }

    func callAsFunction(
        inputEmbeddings: MLXArray,
        caches: inout [KVCache]
    ) -> MLXArray {
        let T = inputEmbeddings.shape[1]
        let offset = caches.first?.seqLen ?? 0

        // Build additive causal mask only during prefill (T > 1)
        let mask: MLXArray?
        if T > 1 {
            let totalLen = offset + T
            // Upper-triangular region = -inf, diagonal + below = 0
            // Shape: (1, 1, T, totalLen) for broadcast over (B, nHeads, T, totalLen)
            let causal = MLX.tril(MLXArray.ones([T, totalLen]))
            let additive = (1.0 - causal.asType(.float32)) * MLXArray(Float(-1e9))
            mask = additive.reshaped([1, 1, T, totalLen])
        } else {
            mask = nil
        }

        var h = inputEmbeddings
        for i in 0..<layers.count {
            h = layers[i](h, mask: mask, cache: &caches[i])
        }
        return norm(h)
    }
}

// MARK: - LlamaWrapper
// Key: "tfmr"  (inside T3Model)
// Holds LlamaInternals at key "model"


@InferenceActor final class LlamaWrapper: Module, @unchecked Sendable {
    @ModuleInfo(key: "model") var model: LlamaInternals

    nonisolated override init() {
        super.init()
        self._model.wrappedValue = LlamaInternals()
    }

    /// Convenience passthrough used by T3Model.
    func callAsFunction(
        inputEmbeddings: MLXArray,
        caches: inout [KVCache]
    ) -> MLXArray {
        return model(inputEmbeddings: inputEmbeddings, caches: &caches)
    }
}
