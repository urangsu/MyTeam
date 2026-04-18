// ChatterboxConfig.swift
import Foundation
import MLX
import MLXNN

// MARK: - Model Paths
struct ModelPaths: Sendable {
    nonisolated static let chatterboxModel = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".cache/huggingface/hub/models--theoracleguy--Chatterbox-Multilingual-MLX-v2-Q4/snapshots/d6c872a42394cbd56f615fd4067805f8570c1e23/model.safetensors")
    nonisolated static let tokenizerJSON = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".cache/huggingface/hub/models--theoracleguy--Chatterbox-Multilingual-MLX-v2-Q4/snapshots/d6c872a42394cbd56f615fd4067805f8570c1e23/tokenizer.json")
    nonisolated static let s3tokenizerModel = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".cache/huggingface/hub/models--mlx-community--S3TokenizerV2/snapshots/e0c9886f0e1c35ae85b1f27277416fb19fc72bec/model.safetensors")
}

// MARK: - Audio Constants
enum AudioConstants: Sendable {
    nonisolated static let s3SR = 16000      // Sample rate for VoiceEncoder and S3Tokenizer
    nonisolated static let s3genSR = 24000   // Sample rate for HiFTGenerator output
}

// MARK: - T3 Constants
enum T3Constants: Sendable {
    nonisolated static let speechVocabSize = 6561  // FSQ codebook size (3^8)
    nonisolated static let sotSpeech = 6561        // start-of-speech token
    nonisolated static let eotSpeech = 6562        // end-of-speech token
    nonisolated static let sotText = 255           // start-of-text token
    nonisolated static let eotText = 0             // end-of-text token
    nonisolated static let speechTokensDictSize = 8194  // speech_vocab + SOT/EOT + padding
    nonisolated static let textTokensDictSize = 2454    // multilingual text vocab

    // T3 Model Config (merged from T3Consts)
    nonisolated static let speakerEmbedSize = 256
    nonisolated static let nChannels = LlamaConfig.hiddenSize  // 1024
    nonisolated static let maxTextTokens = 2048
    nonisolated static let maxSpeechTokens = 4096
    nonisolated static let maxTextSeqLen = 2050   // for pos emb
    nonisolated static let maxMelSeqLen = 4100    // for pos emb
    nonisolated static let perceiverQueryLen = 32
}

// MARK: - LLaMA-520M Config
enum LlamaConfig: Sendable {
    nonisolated static let vocabSize = 4000  // unused in T3 (T3 uses its own text/speech emb)
    nonisolated static let hiddenSize = 1024
    nonisolated static let numHiddenLayers = 30
    nonisolated static let intermediateSize = 4096
    nonisolated static let numAttentionHeads = 16
    nonisolated static let numKeyValueHeads = 16
    nonisolated static let headDim = 64
    nonisolated static let maxPositionEmbeddings = 131072
    nonisolated static let rmsNormEps: Float = 1e-5
    nonisolated static let ropeTheta: Float = 500000.0
    // LLaMA3 RoPE scaling
    nonisolated static let ropeScalingFactor: Float = 8.0
    nonisolated static let ropeHighFreqFactor: Float = 4.0
    nonisolated static let ropeLowFreqFactor: Float = 1.0
    nonisolated static let ropeOrigMaxLen = 8192
    // Quantization
    nonisolated static let quantGroupSize = 64
    nonisolated static let quantBits = 4
}

// MARK: - VoiceEncoder Config
enum VoiceEncConfig: Sendable {
    nonisolated static let numMels = 40
    nonisolated static let sampleRate = 16000
    nonisolated static let speakerEmbedSize = 256
    nonisolated static let hiddenSize = 256
    nonisolated static let nFft = 400
    nonisolated static let hopSize = 160
    nonisolated static let winSize = 400
    nonisolated static let fmax: Float = 8000
    nonisolated static let fmin: Float = 0
    nonisolated static let partialFrames = 160
}


