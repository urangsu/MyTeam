import Foundation
import MLX

// MARK: - T3 Config
struct T3Config: Sendable {
    let hiddenSize: Int     = 1024
    let numLayers: Int      = 30
    let numHeads: Int       = 16
    let headDim: Int        = 64  // hiddenSize / numHeads
    let intermediateSize: Int = 4096
    let numCondTokens: Int  = 8   // embed_tokens.weight rows

    // t3_config.json
    let startTextToken: Int32   = 255
    let stopTextToken: Int32    = 0
    let startSpeechToken: Int32 = 6561
    let stopSpeechToken: Int32  = 6562
    let speechCondPromptLen: Int = 150
    let rmsNormEps: Float       = 1e-5
    let ropeTheta: Float        = 10000.0

    nonisolated init() {}
}

// MARK: - Per-Layer Weights
@InferenceActor
struct T3LayerWeights: @unchecked Sendable {
    let inputLayerNorm: MLXArray         // (hidden,)
    let postAttentionLayerNorm: MLXArray // (hidden,)
    let qProj: MLXArray                  // (hidden, hidden)
    let kProj: MLXArray                  // (hidden, hidden)
    let vProj: MLXArray                  // (hidden, hidden)
    let oProj: MLXArray                  // (hidden, hidden)
    let gateProj: MLXArray               // (inter, hidden)
    let upProj: MLXArray                 // (inter, hidden)
    let downProj: MLXArray               // (hidden, inter)
}

// MARK: - KV Cache (per-layer)
@InferenceActor
struct LayerKVCache: @unchecked Sendable {
    var k: MLXArray  // (seq_len, n_heads, head_dim) — grows with each token
    var v: MLXArray  // (seq_len, n_heads, head_dim)
}

// MARK: - T3MLXModel
/// Chatterbox T3: Llama-style AR transformer (30-layer, hidden=1024, FP16 가중치)
/// Zero-Shot TTS: 텍스트 토큰 + 화자 임베딩 → 음성 토큰 AR 디코딩
@InferenceActor
final class T3MLXModel {
    let config: T3Config

    // Transformer
    private let condEmbedWeight: MLXArray    // (8, 1024) — 조건 토큰 임베딩
    private let normWeight: MLXArray         // (1024,)   — 최종 RMSNorm
    private let speechHeadWeight: MLXArray   // (8194, 1024) — speech vocab 출력 헤드

    private let layerWeights: [T3LayerWeights]

    // Embedding 테이블 (별도 .npy)
    private let textEmbWeight: MLXArray      // (2454, 1024)
    private let speechEmbWeight: MLXArray    // (8194, 1024)
    private let textPosEmbWeight: MLXArray   // (2050, 1024)
    private let speechPosEmbWeight: MLXArray // (4100, 1024)

    // 화자 인코더: 256-dim xvector → 1024-dim 조건 벡터
    private let spkrEncWeight: MLXArray      // (1024, 256)
    private let spkrEncBias: MLXArray        // (1024,)

    // MARK: - Init (MLX.loadArrays .safetensors 순정 로더)
    init(weightsURL: URL, embeddingURLs: T3EmbeddingURLs) throws {
        self.config = T3Config()
        // MLX-Swift 순정 loadArrays: .safetensors만 지원 — Zero-Copy Memory Mapped
        // (수석 아키텍트가 npz → safetensors 변환 후 번들 배치)
        let w = try MLX.loadArrays(url: weightsURL)

        func require(_ key: String) throws -> MLXArray {
            guard let v = w[key] else {
                throw MLXModelError.weightsNotFound(key)
            }
            return v
        }

        condEmbedWeight  = try require("embed_tokens.weight")
        normWeight       = try require("norm.weight")
        speechHeadWeight = try require("speech_head.weight")

        layerWeights = try (0..<30).map { i in
            T3LayerWeights(
                inputLayerNorm:         try require("layers.\(i).input_layernorm.weight"),
                postAttentionLayerNorm: try require("layers.\(i).post_attention_layernorm.weight"),
                qProj:                  try require("layers.\(i).self_attn.q_proj.weight"),
                kProj:                  try require("layers.\(i).self_attn.k_proj.weight"),
                vProj:                  try require("layers.\(i).self_attn.v_proj.weight"),
                oProj:                  try require("layers.\(i).self_attn.o_proj.weight"),
                gateProj:               try require("layers.\(i).mlp.gate_proj.weight"),
                upProj:                 try require("layers.\(i).mlp.up_proj.weight"),
                downProj:               try require("layers.\(i).mlp.down_proj.weight")
            )
        }

        // 임베딩 .npy 파일 로드 (Memory Mapped Data)
        textEmbWeight      = try T3MLXModel.loadNPY(url: embeddingURLs.textEmb)
        speechEmbWeight    = try T3MLXModel.loadNPY(url: embeddingURLs.speechEmb)
        textPosEmbWeight   = try T3MLXModel.loadNPY(url: embeddingURLs.textPosEmb)
        speechPosEmbWeight = try T3MLXModel.loadNPY(url: embeddingURLs.speechPosEmb)
        spkrEncWeight      = try T3MLXModel.loadNPY(url: embeddingURLs.spkrEncWeight)
        spkrEncBias        = try T3MLXModel.loadNPY(url: embeddingURLs.spkrEncBias)

        print("[T3MLXModel] ✅ safetensors 로드 완료 (\(w.count)개 텐서, 30-layer Llama FP16)")
    }

    // MARK: - Generate Speech Tokens (AR Decoding with KV Cache)
    /// - Parameters:
    ///   - textTokenIds: BPE 토크나이저 출력 (start/stop 토큰 포함)
    ///   - speakerEmbedding: ve.onnx 출력 xvector (256-dim)
    ///   - maxTokens: 입력 길이 비례 동적 설정 권장 (len * 6, 최대 600)
    /// - Returns: 음성 토큰 배열 (stop 토큰 미포함)
    func generate(textTokenIds: [Int32], speakerEmbedding: [Float32], maxTokens: Int) -> [Int32] {
        let H = config.hiddenSize

        // 1. 화자 임베딩: xvector (256) → 조건 벡터 (1024)
        //    spkrEncWeight: (1024, 256) → Linear(256→1024): output = W @ x + b
        let xvec = MLXArray(speakerEmbedding)  // (256,)
        let spkrCond = MLX.matmul(spkrEncWeight, xvec.reshaped([256, 1]))
            .reshaped([H]) + spkrEncBias       // (1024,)

        // 2. 조건 토큰 시퀀스 구성 (8개 학습된 조건 토큰 + 화자 조건 주입)
        let condTokens = (0..<config.numCondTokens).map { i -> MLXArray in
            condEmbedWeight[i] + spkrCond  // (1024,) × 8
        }

        // 3. 텍스트 토큰 임베딩 + 위치 임베딩
        var textEmbeds: [MLXArray] = []
        for (i, tokenId) in textTokenIds.enumerated() {
            let te = textEmbWeight[Int(tokenId)]          // (1024,)
            let pe = textPosEmbWeight[i]                   // (1024,)
            textEmbeds.append(te + pe)
        }

        // 4. Prefill: [cond(8) + text(T)] 시퀀스 전체 포워드 → KV 캐시 구축
        let prefillSeq = condTokens + textEmbeds           // (8+T, 1024)
        let prefillInput = MLX.stacked(prefillSeq, axis: 0) // (8+T, 1024)
        var kvCaches: [LayerKVCache?] = Array(repeating: nil, count: config.numLayers)
        let prefillPos = Array(0..<prefillSeq.count)
        _ = forwardSequence(prefillInput, positions: prefillPos, kvCaches: &kvCaches)

        // 5. AR 디코딩: START_SPEECH 토큰부터 시작
        var speechTokens: [Int32] = []
        var currentToken = config.startSpeechToken
        let prefillLen = prefillSeq.count

        for step in 0..<maxTokens {
            let pos = prefillLen + step
            let se = speechEmbWeight[Int(currentToken)]    // (1024,)
            let pe = speechPosEmbWeight[step]               // (1024,)
            var x = (se + pe).reshaped([1, H])              // (1, 1024)

            // 단일 토큰 forward (KV 캐시 활용 → O(n) per step)
            x = forwardSequence(x, positions: [pos], kvCaches: &kvCaches)

            // 출력 헤드: logits over speech vocab (8194)
            let normed = rmsNorm(x[0], weight: normWeight)
            let logits = MLX.matmul(speechHeadWeight, normed.reshaped([H, 1])).reshaped([speechHeadWeight.shape[0]])

            // Greedy 디코딩 (argmax)
            let nextToken = Int32(MLX.argMax(logits, axis: 0).item(Int.self))

            if nextToken == config.stopSpeechToken { break }
            speechTokens.append(nextToken)
            currentToken = nextToken
        }

        print("[T3MLXModel] 🎵 AR 디코딩 완료 — \(speechTokens.count)개 음성 토큰 생성")
        return speechTokens
    }

    // MARK: - Full Sequence Forward (Prefill & Single-Step Decode 공용)
    @discardableResult
    private func forwardSequence(
        _ input: MLXArray,
        positions: [Int],
        kvCaches: inout [LayerKVCache?]
    ) -> MLXArray {
        var x = input  // (seq_len, hidden)

        for (i, layer) in layerWeights.enumerated() {
            // Pre-attention RMSNorm
            let normedAttn = rmsNorm(x, weight: layer.inputLayerNorm)

            // Self-attention + residual
            let attnOut = selfAttention(normedAttn, layer: layer, positions: positions, kvCache: &kvCaches[i])
            x = x + attnOut

            // Pre-FFN RMSNorm
            let normedFFN = rmsNorm(x, weight: layer.postAttentionLayerNorm)

            // SwiGLU FFN + residual
            x = x + swiglu(normedFFN, layer: layer)
        }

        return x
    }

    // MARK: - Self-Attention with RoPE + KV Cache
    private func selfAttention(
        _ x: MLXArray,
        layer: T3LayerWeights,
        positions: [Int],
        kvCache: inout LayerKVCache?
    ) -> MLXArray {
        let seqLen = x.shape[0]
        let H = config.hiddenSize
        let nH = config.numHeads
        let hD = config.headDim

        // Q, K, V 프로젝션 (편향 없음)
        // weight: (H, H), x: (seq, H) → output: (seq, H)
        let q = MLX.matmul(x, layer.qProj.T).reshaped([seqLen, nH, hD])
        var k = MLX.matmul(x, layer.kProj.T).reshaped([seqLen, nH, hD])
        let v = MLX.matmul(x, layer.vProj.T).reshaped([seqLen, nH, hD])

        // RoPE 적용
        let qRoped = applyRoPE(q, positions: positions)
        let kRoped = applyRoPE(k, positions: positions)
        k = kRoped

        // KV 캐시 업데이트 (이전 K,V 이어붙이기)
        let fullK: MLXArray
        let fullV: MLXArray
        if let cache = kvCache {
            fullK = MLX.concatenated([cache.k, kRoped], axis: 0)
            fullV = MLX.concatenated([cache.v, v], axis: 0)
        } else {
            fullK = kRoped
            fullV = v
        }
        kvCache = LayerKVCache(k: fullK, v: fullV)

        // Scaled Dot-Product Attention
        // q: (seq, nH, hD) → (nH, seq, hD)
        // k: (full, nH, hD) → (nH, full, hD)
        let qT = qRoped.transposed(1, 0, 2)   // (nH, seq, hD)
        let kT = fullK.transposed(1, 0, 2)    // (nH, full, hD)
        let vT = fullV.transposed(1, 0, 2)    // (nH, full, hD)

        let scale = 1.0 / sqrt(Float(hD))
        // scores: (nH, seq, full)
        let scores = MLX.matmul(qT, kT.transposed(0, 2, 1)) * scale
        let attnWeights = MLX.softmax(scores, axis: -1)

        // attended: (nH, seq, hD) → (seq, nH, hD) → (seq, H)
        let attended = MLX.matmul(attnWeights, vT)
            .transposed(1, 0, 2)
            .reshaped([seqLen, H])

        // 출력 프로젝션
        return MLX.matmul(attended, layer.oProj.T)
    }

    // MARK: - RoPE (Rotary Position Embedding)
    private func applyRoPE(_ x: MLXArray, positions: [Int]) -> MLXArray {
        // x: (seq_len, n_heads, head_dim)
        let seqLen = x.shape[0]
        let nH = config.numHeads
        let hD = config.headDim
        let halfDim = hD / 2
        let theta = config.ropeTheta

        // 코사인/사인 행렬 계산
        var cosVals = [Float32]()
        var sinVals = [Float32]()
        cosVals.reserveCapacity(seqLen * nH * halfDim)
        sinVals.reserveCapacity(seqLen * nH * halfDim)

        for pos in positions {
            for _ in 0..<nH {
                for i in 0..<halfDim {
                    let freq = Float(pow(Double(theta), -2.0 * Double(i) / Double(hD)))
                    let angle = Float(pos) * freq
                    cosVals.append(Foundation.cos(angle))
                    sinVals.append(Foundation.sin(angle))
                }
            }
        }

        let cosArr = MLXArray(cosVals).reshaped([seqLen, nH, halfDim])
        let sinArr = MLXArray(sinVals).reshaped([seqLen, nH, halfDim])

        // x를 두 절반으로 분리
        let halves = MLX.split(x, parts: 2, axis: 2)  // 각각 (seq, nH, halfDim)
        let x1 = halves[0]
        let x2 = halves[1]

        // 회전 적용: [x1, x2] → [x1*cos - x2*sin, x1*sin + x2*cos]
        let rotated1 = x1 * cosArr - x2 * sinArr
        let rotated2 = x1 * sinArr + x2 * cosArr

        return MLX.concatenated([rotated1, rotated2], axis: 2)
    }

    // MARK: - SwiGLU FFN
    private func swiglu(_ x: MLXArray, layer: T3LayerWeights) -> MLXArray {
        // gate_proj: (inter, hidden), up_proj: (inter, hidden), down_proj: (hidden, inter)
        let gate = MLX.matmul(x, layer.gateProj.T)  // (seq, inter)
        let up   = MLX.matmul(x, layer.upProj.T)    // (seq, inter)
        // SiLU(gate) * up
        let activated = gate * MLX.sigmoid(gate) * up
        return MLX.matmul(activated, layer.downProj.T)  // (seq, hidden)
    }

    // MARK: - RMSNorm
    private func rmsNorm(_ x: MLXArray, weight: MLXArray, eps: Float = 1e-5) -> MLXArray {
        // x: (..., hidden), weight: (hidden,)
        let variance = MLX.mean(x * x, axis: -1, keepDims: true)
        let normalized = x * MLX.rsqrt(variance + eps)
        return normalized * weight
    }

    // MARK: - NPY File Loader (Memory Mapped)
    static func loadNPY(url: URL) throws -> MLXArray {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try T3MLXModel.parseNPYData(data, name: url.lastPathComponent)
    }

    /// NPY 바이너리 파싱 — shape + dtype 헤더 포함 완전 파싱
    static func parseNPYData(_ data: Data, name: String = "?") throws -> MLXArray {
        guard data.count > 10 else { throw MLXModelError.embeddingNotFound(name) }
        let majorVersion = data[6]
        let hlo = 8
        let headerLenSize = majorVersion == 1 ? 2 : 4
        let headerLen: Int
        if majorVersion == 1 {
            headerLen = Int(data[hlo]) | (Int(data[hlo+1]) << 8)
        } else {
            headerLen = Int(data[hlo]) | (Int(data[hlo+1]) << 8)
                      | (Int(data[hlo+2]) << 16) | (Int(data[hlo+3]) << 24)
        }
        let headerStart = 6 + 2 + headerLenSize
        let dataStart   = headerStart + headerLen
        guard dataStart <= data.count else { throw MLXModelError.embeddingNotFound(name) }

        let headerStr = String(data: data.subdata(in: headerStart..<(headerStart + headerLen)),
                               encoding: .ascii) ?? ""
        let shape  = parseNPYShape(headerStr)
        let isFP16 = headerStr.contains("'<f2'") || headerStr.contains("\"<f2\"") ||
                     headerStr.contains("'|f2'") || headerStr.contains("float16")

        let rawData = data.subdata(in: dataStart..<data.count)
        let arr: MLXArray
        if isFP16 {
            let count = rawData.count / 2
            let floats: [Float32] = rawData.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return [] }
                let u16 = base.assumingMemoryBound(to: UInt16.self)
                return (0..<count).map { Float32(Float16(bitPattern: u16[$0])) }
            }
            arr = MLXArray(floats)
        } else {
            let count = rawData.count / MemoryLayout<Float32>.size
            let floats: [Float32] = rawData.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return [] }
                return Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: Float32.self),
                                                 count: count))
            }
            arr = MLXArray(floats)
        }
        guard !shape.isEmpty else { return arr }
        return arr.reshaped(shape)
    }

    /// NPY 헤더 문자열에서 shape 추출 — ex) "'shape': (1024, 256)" → [1024, 256]
    private static func parseNPYShape(_ header: String) -> [Int] {
        guard let keyRange = header.range(of: "'shape'") ?? header.range(of: "\"shape\"") else { return [] }
        let afterKey = header[keyRange.upperBound...]
        guard let openParen  = afterKey.firstIndex(of: "("),
              let closeParen = afterKey.firstIndex(of: ")") else { return [] }
        let content = afterKey[afterKey.index(after: openParen)..<closeParen]
            .trimmingCharacters(in: .whitespaces)
        if content.isEmpty { return [] }  // scalar ()
        return content.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

}
