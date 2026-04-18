// VoiceEncoder.swift
import Foundation
import MLX
import MLXNN
import MLXRandom

// MARK: - Stacked LSTM

/// Wraps 3 MLXNN.LSTM layers and returns the final hidden state of the last layer.
/// Input:  (B, T, inputSize)
/// Output: (B, hiddenSize) — last time-step of the last LSTM layer
@InferenceActor final class StackedLSTM: Module, @unchecked Sendable {
    var layers: [MLXNN.LSTM]

    nonisolated init(inputSize: Int, hiddenSize: Int, numLayers: Int) {
        var lstmLayers = [MLXNN.LSTM]()
        for i in 0..<numLayers {
            let inSize = i == 0 ? inputSize : hiddenSize
            lstmLayers.append(MLXNN.LSTM(inputSize: inSize, hiddenSize: hiddenSize))
        }
        self.layers = lstmLayers
        super.init()
    }

    nonisolated override init() {
        fatalError("Use init(inputSize:hiddenSize:numLayers:)")
    }

    
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: (B, T, inputSize)
        var current = x
        var lastH = zeros([x.dim(0), layers[0].hiddenSize])

        for layer in layers {
            // MLXNN.LSTM returns (all_h, all_c), all_h: (B, T, hiddenSize)
            let (allH, _) = layer(current)
            current = allH  // pass full sequence to next layer

            // Extract last time step: (B, T, H) → (B, H)
            let T = allH.dim(1)
            // Use MLX.take to select index T-1 along axis 1 → (B, 1, H) → squeeze → (B, H)
            let lastIdx = MLXArray([Int32(T - 1)])
            lastH = MLX.take(allH, lastIdx, axis: 1).squeezed(axis: 1)
        }
        return lastH  // (B, hiddenSize)
    }
}

// MARK: - VoiceEncoder

/// LSTM-based speaker embedding extractor.
///
/// Weight key layout (from Python model):
///   ve.lstm.layers.0.Wx      (1024, 40)
///   ve.lstm.layers.0.Wh      (1024, 256)
///   ve.lstm.layers.0.bias    (1024,)
///   ve.lstm.layers.1.Wx      (1024, 256)
///   ve.lstm.layers.1.Wh      (1024, 256)
///   ve.lstm.layers.1.bias    (1024,)
///   ve.lstm.layers.2.Wx      (1024, 256)
///   ve.lstm.layers.2.Wh      (1024, 256)
///   ve.lstm.layers.2.bias    (1024,)
///   ve.proj.weight           (256, 256)
///   ve.proj.bias             (256,)
///   ve.similarity_weight     (1,)
///   ve.similarity_bias       (1,)
///
/// Forward:
///   Input  mel: (B, T, 40)
///   Output emb: (B, 256)  — L2-normalised speaker embedding
@InferenceActor final class VoiceEncoder: Module, @unchecked Sendable {
    @ModuleInfo(key: "lstm") var lstm: StackedLSTM
    @ModuleInfo(key: "proj") var proj: Linear

    // Learnable cosine-similarity calibration scalars
    @ParameterInfo(key: "similarity_weight") var similarityWeight: MLXArray
    @ParameterInfo(key: "similarity_bias")   var similarityBias: MLXArray

    nonisolated override init() {
        let numMels = VoiceEncConfig.numMels
        let hiddenSize = VoiceEncConfig.hiddenSize
        let embedSize = VoiceEncConfig.speakerEmbedSize
        
        let lstm = StackedLSTM(inputSize: numMels, hiddenSize: hiddenSize, numLayers: 3)
        let proj = Linear(hiddenSize, embedSize)
        
        super.init()
        
        // Use InferenceActor.run or similar? No, just initialize storage.
        // In Swift 6, we can use nonisolated(unsafe) for the storage or just trust the init.
        // For now, let's try the most basic approach.
    }

    /// Forward pass.
    /// - Parameter mel: shape (B, T, 40) — batch of mel spectrograms
    /// - Returns: shape (B, 256) — L2-normalised speaker embeddings
    
    func callAsFunction(_ mel: MLXArray) -> MLXArray {
        // 1. Run stacked LSTM → (B, hiddenSize)
        let finalHidden = lstm(mel)

        // 2. Projection linear layer → (B, embedSize)
        let rawEmbeds = proj(finalHidden)

        // 3. ReLU (ve_final_relu = True in Python config)
        let reluEmbeds = MLXNN.relu(rawEmbeds)

        // 4. L2-normalise along embedding axis → (B, embedSize)
        let norm = MLX.sqrt(
            (reluEmbeds * reluEmbeds).sum(axes: [1], keepDims: true)
        )
        let embeds = reluEmbeds / (norm + 1e-8)

        return embeds  // (B, 256)
    }

    /// Compute cosine similarity between two embedding batches.
    /// Applies the learned weight and bias calibration.
    /// - Parameters:
    ///   - embeds1: (B, embedSize)
    ///   - embeds2: (B, embedSize)
    /// - Returns: (B,) similarity scores
    func cosineSimilarity(_ embeds1: MLXArray, _ embeds2: MLXArray) -> MLXArray {
        let dot = (embeds1 * embeds2).sum(axes: [1])
        let norm1 = MLX.sqrt((embeds1 * embeds1).sum(axes: [1]))
        let norm2 = MLX.sqrt((embeds2 * embeds2).sum(axes: [1]))
        let cosine = dot / (norm1 * norm2 + 1e-8)
        return similarityWeight * cosine + similarityBias
    }
}

// MARK: - Convenience: embed a single audio clip

extension VoiceEncoder {
    /// Compute a speaker embedding for a single 16kHz waveform.
    /// - Parameter wav: 1D MLXArray of float32 samples at 16kHz
    /// - Returns: (256,) speaker embedding
    
    func embed(wav: MLXArray) -> MLXArray {
        // Build mel spectrogram: (40, T)
        let mel = voiceEncMelSpectrogram(wav: wav)  // (40, T)

        // Transpose and add batch dim: (1, T, 40)
        let melBatched = mel.transposed(1, 0).reshaped([1, mel.dim(1), mel.dim(0)])

        // Forward → (1, 256)
        let embeds = callAsFunction(melBatched)

        // Remove batch dim → (256,)
        return embeds.reshaped([VoiceEncConfig.speakerEmbedSize])
    }

    /// Embed multiple partial frames of a waveform and return the mean embedding.
    /// This mirrors the Python `embed_utterance` approach for robustness.
    /// - Parameters:
    ///   - wav: 1D float32 waveform at 16kHz
    ///   - partialFrames: number of mel frames per partial clip (default 160)
    ///   - partialOverlap: overlap between clips in frames (default 0)
    /// - Returns: (256,) mean-pooled, L2-normalised speaker embedding
    
    func embedUtterance(
        wav: MLXArray,
        partialFrames: Int = VoiceEncConfig.partialFrames,
        partialOverlap: Int = 0
    ) -> MLXArray {
        let hop = VoiceEncConfig.hopSize      // 160 samples per mel frame
        let chunkSamples = partialFrames * hop
        let stepSamples = (partialFrames - partialOverlap) * hop

        let sigLen = wav.dim(0)
        guard sigLen >= chunkSamples else {
            // Short clip: embed the whole thing
            return embed(wav: wav)
        }

        var partialEmbeds = [MLXArray]()
        var start = 0
        while start + chunkSamples <= sigLen {
            let chunk = wav[start..<(start + chunkSamples)]
            partialEmbeds.append(embed(wav: chunk))
            start += stepSamples
        }

        // Stack → (N, 256), mean-pool → (256,), re-normalise
        let stacked = stacked(partialEmbeds, axis: 0)  // (N, 256)
        let mean = stacked.mean(axes: [0])              // (256,)
        let norm = MLX.sqrt((mean * mean).sum())
        return mean / (norm + 1e-8)
    }
}
