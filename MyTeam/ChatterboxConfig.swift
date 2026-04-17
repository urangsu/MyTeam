// ChatterboxConfig.swift
import Foundation
import MLX
import MLXNN

// MARK: - Model Paths
struct ModelPaths: Sendable {
    static let chatterboxModel = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".cache/huggingface/hub/models--theoracleguy--Chatterbox-Multilingual-MLX-v2-Q4/snapshots/d6c872a42394cbd56f615fd4067805f8570c1e23/model.safetensors")
    static let tokenizerJSON = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".cache/huggingface/hub/models--theoracleguy--Chatterbox-Multilingual-MLX-v2-Q4/snapshots/d6c872a42394cbd56f615fd4067805f8570c1e23/tokenizer.json")
    static let s3tokenizerModel = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".cache/huggingface/hub/models--mlx-community--S3TokenizerV2/snapshots/e0c9886f0e1c35ae85b1f27277416fb19fc72bec/model.safetensors")
}

// MARK: - Audio Constants
enum AudioConstants: Sendable {
    static let s3SR = 16000      // Sample rate for VoiceEncoder and S3Tokenizer
    static let s3genSR = 24000   // Sample rate for HiFTGenerator output
}

// MARK: - T3 Constants
enum T3Constants: Sendable {
    static let speechVocabSize = 6561  // FSQ codebook size (3^8)
    static let sotSpeech = 6561        // start-of-speech token
    static let eotSpeech = 6562        // end-of-speech token
    static let sotText = 255           // start-of-text token
    static let eotText = 0             // end-of-text token
    static let speechTokensDictSize = 8194  // speech_vocab + SOT/EOT + padding
    static let textTokensDictSize = 2454    // multilingual text vocab

    // T3 Model Config (merged from T3Consts)
    static let speakerEmbedSize = 256
    static let nChannels = LlamaConfig.hiddenSize  // 1024
    static let maxTextTokens = 2048
    static let maxSpeechTokens = 4096
    static let maxTextSeqLen = 2050   // for pos emb
    static let maxMelSeqLen = 4100    // for pos emb
    static let perceiverQueryLen = 32
}

// MARK: - LLaMA-520M Config
enum LlamaConfig: Sendable {
    static let vocabSize = 4000  // unused in T3 (T3 uses its own text/speech emb)
    static let hiddenSize = 1024
    static let numHiddenLayers = 30
    static let intermediateSize = 4096
    static let numAttentionHeads = 16
    static let numKeyValueHeads = 16
    static let headDim = 64
    static let maxPositionEmbeddings = 131072
    static let rmsNormEps: Float = 1e-5
    static let ropeTheta: Float = 500000.0
    // LLaMA3 RoPE scaling
    static let ropeScalingFactor: Float = 8.0
    static let ropeHighFreqFactor: Float = 4.0
    static let ropeLowFreqFactor: Float = 1.0
    static let ropeOrigMaxLen = 8192
    // Quantization
    static let quantGroupSize = 64
    static let quantBits = 4
}

// MARK: - VoiceEncoder Config
enum VoiceEncConfig: Sendable {
    static let numMels = 40
    static let sampleRate = 16000
    static let speakerEmbedSize = 256
    static let hiddenSize = 256
    static let nFft = 400
    static let hopSize = 160
    static let winSize = 400
    static let fmax: Float = 8000
    static let fmin: Float = 0
    static let partialFrames = 160
}


