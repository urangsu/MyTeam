// HiFTGenerator.swift
// Chatterbox TTS — HiFT vocoder: mel → audio waveform
//
// Weight key hierarchy (after stripping global "s3gen." prefix):
//   conv_pre.weight                    (512, 7, 80)   Conv1d
//   conv_post.weight                   (18, 7, 64)    Conv1d
//   resblocks.N.convs1.M.weight        (C, k, C)      Conv1d (dilated)
//   resblocks.N.activations1.M.alpha   (C,)           Snake
//   resblocks.N.convs2.M.weight        (C, k, C)      Conv1d
//   resblocks.N.activations2.M.alpha   (C,)           Snake
//   f0_predictor.condnet.N.weight      …              Conv1d
//   f0_predictor.classifier.weight     (1, C)         Linear
//   m_source.l_linear.weight           (1, 9)         Linear

import MLX
import MLXNN
import MLXRandom
import Foundation

// MARK: - Snake Activation

/// Periodic activation: x + (1/|α|) * sin²(αx)
/// Alpha shape: (channels,) — one learnable parameter per channel.
/// Expects channels-first layout: (B, C, T).

final class Snake: Module, @unchecked Sendable {
    @ParameterInfo(key: "alpha") var alpha: MLXArray  // (C,)

    nonisolated override init() { fatalError() }

    init(channels: Int) {
        self._alpha.wrappedValue = MLXArray.ones([channels])
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: (B, C, T)
        let a = alpha.reshaped([1, -1, 1])  // (1, C, 1)
        // Clamp to avoid division by zero
        let minVal = MLXArray(Float(1e-4))
        let sign  = MLX.which(a .>= MLXArray(Float(0)), MLXArray(Float(1.0)), MLXArray(Float(-1.0)))
        let aClamped = MLX.maximum(MLX.abs(a), minVal) * sign
        return x + (MLXArray(Float(1.0)) / aClamped) * MLX.pow(MLX.sin(x * a), MLXArray(Float(2.0)))
    }
}

// MARK: - HiFT ResBlock

/// One residual block: two stacks of [Snake → Conv1d] pairs, skip connection.
/// Operates in channels-first format (B, C, T). Conv1d in MLX-Swift expects
/// NLC (B, T, C), so we transpose in/out around each Conv1d call.

final class HiFTResBlock: Module, @unchecked Sendable {
    var convs1: [Conv1d]       // key "convs1"
    var convs2: [Conv1d]       // key "convs2"
    var activations1: [Snake]  // key "activations1"
    var activations2: [Snake]  // key "activations2"

    /// - Parameters:
    ///   - channels: number of feature channels
    ///   - kernelSize: kernel size for convs
    ///   - dilations: list of dilation values, one per sub-layer pair
    nonisolated override init() { fatalError() }

    init(channels: Int, kernelSize: Int = 3, dilations: [Int] = [1, 3, 5]) {
        var c1 = [Conv1d]()
        var c2 = [Conv1d]()
        var a1 = [Snake]()
        var a2 = [Snake]()
        for d in dilations {
            c1.append(Conv1d(inputChannels: channels, outputChannels: channels,
                             kernelSize: kernelSize, padding: d, dilation: d))
            c2.append(Conv1d(inputChannels: channels, outputChannels: channels,
                             kernelSize: kernelSize, padding: 1, dilation: 1))
            a1.append(Snake(channels: channels))
            a2.append(Snake(channels: channels))
        }
        self.convs1 = c1
        self.convs2 = c2
        self.activations1 = a1
        self.activations2 = a2
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: (B, C, T) channels-first
        var h = x
        for i in 0..<convs1.count {
            var xt = activations1[i](h)           // Snake: (B, C, T)
            xt = xt.transposed(0, 2, 1)           // → (B, T, C) for Conv1d
            xt = convs1[i](xt)                    // Conv1d: (B, T, C)
            xt = xt.transposed(0, 2, 1)           // → (B, C, T)
            xt = activations2[i](xt)
            xt = xt.transposed(0, 2, 1)
            xt = convs2[i](xt)
            xt = xt.transposed(0, 2, 1)
            h = h + xt                            // residual
        }
        return h
    }
}

// MARK: - ConvRNNF0Predictor

/// Predicts normalised F0 from mel spectrogram using a stack of dilated Conv1d layers.
/// Input:  (B, T, 80) mel
/// Output: (B, T, 1) F0 in [0, 1] range

@InferenceActor final class ConvRNNF0Predictor: Module, @unchecked Sendable {
    var condnet: [Conv1d]  // key "condnet", 5 layers: "condnet.0" … "condnet.4"
    @ModuleInfo(key: "classifier") var classifier: Linear  // (C → 1)

    nonisolated override init() { fatalError("Use init(inChannels:hidChannels:numLayers:)") }

    init(
        inChannels: Int = 80,
        hidChannels: Int = 512,
        numLayers: Int = 5
    ) {
        var layers = [Conv1d]()
        for i in 0..<numLayers {
            let inC = i == 0 ? inChannels : hidChannels
            // Dilations: 1,2,4,8,1 — typical for condnets
            let d = [1, 2, 4, 8, 1][i % 5]
            layers.append(Conv1d(inputChannels: inC, outputChannels: hidChannels,
                                 kernelSize: 3, padding: d, dilation: d))
        }
        self.condnet = layers
        self._classifier.wrappedValue = Linear(hidChannels, 1)
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // x: (B, T, 80) mel — Conv1d already expects NLC, so no transpose needed
        var h = x  // (B, T, 80)
        for conv in condnet {
            h = relu(conv(h))  // (B, T, hidChannels)
        }
        return sigmoid(classifier(h))  // (B, T, 1)
    }
}

// MARK: - SourceModuleHnNSF

/// Generates a harmonic-noise source signal from predicted F0.
/// Weights: l_linear.weight (1, numHarmonics) + l_linear.bias (1,)

@InferenceActor final class SourceModuleHnNSF: Module, @unchecked Sendable {
    @ModuleInfo(key: "l_linear") var lLinear: Linear  // (numHarmonics → 1)

    let sampleRate: Float
    let numHarmonics: Int

    nonisolated override init() { fatalError() }

    init(sampleRate: Float = 24000, numHarmonics: Int = 9) {
        self.sampleRate   = sampleRate
        self.numHarmonics = numHarmonics
        self._lLinear.wrappedValue = Linear(numHarmonics, 1)
        super.init()
    }

    /// Generate source signal from frame-level F0.
    /// - Parameters:
    ///   - f0Norm: (B, T_frames, 1) normalised F0 in [0,1]
    ///   - hopLen: samples per frame (e.g. 480 for 24kHz / 50 fps)
    /// - Returns: (B, T_frames * hopLen, 1) source waveform
    func callAsFunction(_ f0Norm: MLXArray, hopLen: Int = 480) -> MLXArray {
        let B       = f0Norm.shape[0]
        let T       = f0Norm.shape[1]          // number of mel frames
        let nSamples = T * hopLen

        // Convert normalised F0 → Hz (map 0→0 Hz, 1→sampleRate/2)
        let f0Hz = f0Norm.squeezed(axis: -1) * MLXArray(sampleRate / 2.0)
        // (B, T) in Hz, one value per frame

        // Upsample frame-level F0 to sample-level by repeating each frame hopLen times
        // (B, T) → (B, T, 1) → repeat along the frame axis
        let f0Expanded = f0Hz.reshaped([B, T, 1])  // (B, T, 1)
        // Use broadcast: tile hopLen times on a new axis then reshape
        // MLX: repeated(count:axis:)
        let f0Upsampled = MLX.repeated(f0Expanded, count: hopLen, axis: 2)  // (B, T, hopLen)
                                    .reshaped([B, nSamples])              // (B, nSamples)

        // Instantaneous phase: cumulative sum of (F0 / sampleRate)  → in cycles
        let instPhase = cumsum(f0Upsampled / MLXArray(sampleRate), axis: 1)  // (B, nSamples)

        // Generate harmonics: sin(2π * k * phase) for k = 1..numHarmonics
        var harmonics = [MLXArray]()
        for k in 1...numHarmonics {
            harmonics.append(MLX.sin(instPhase * MLXArray(Float(2.0 * .pi * Float(k)))))
        }
        // Stack: (B, nSamples, numHarmonics)
        let harmStack = stacked(harmonics, axis: -1)  // (B, nSamples, numHarmonics)

        // Mix harmonics: lLinear (numHarmonics → 1)
        let src = lLinear(harmStack)  // (B, nSamples, 1)
        return src
    }
}

// MARK: - HiFTGenerator

/// HiFT vocoder: converts mel spectrogram → audio waveform.
///
/// Pipeline:
///   1. Predict F0 from mel via ConvRNNF0Predictor
///   2. Generate harmonic source signal via SourceModuleHnNSF
///   3. conv_pre → ResBlocks → conv_post (spectral feature extraction)
///   4. iSTFT-style synthesis to produce final audio
///
/// Input:  (B, T, 80)   mel spectrogram (24kHz, hop=480)
/// Output: (audioLen,)  mono waveform at 24kHz (first batch item)

@InferenceActor final class HiFTGenerator: Module, @unchecked Sendable {
    @ModuleInfo(key: "conv_pre")     var convPre:     Conv1d
    var resblocks:                   [HiFTResBlock]   // key "resblocks"
    @ModuleInfo(key: "conv_post")    var convPost:    Conv1d
    @ModuleInfo(key: "f0_predictor") var f0Predictor: ConvRNNF0Predictor
    @ModuleInfo(key: "m_source")     var mSource:     SourceModuleHnNSF

    // iSTFT parameters
    let nFft:        Int = 20
    let hopLength:   Int = 5
    let numHarmonics: Int = 8     // conv_post outputs 2*numHarmonics+1? = 17 or 18
    let preChannels: Int = 512    // conv_pre output channels
    let resChannels: Int = 256    // resblock channels (halved each upsample stage)
    let postChannels: Int = 64    // conv_post input channels
    let outputChannels: Int = 18  // conv_post output: 9 real + 9 imag spectral bins
    let sampleRate: Float = 24000
    let melHop: Int = 480         // upsampling factor: 24000 / 50fps = 480

    nonisolated override init() {
        // 1. Initialize non-wrapped properties first
        var rbs = [HiFTResBlock]()
        let rbChannelSeq = [512, 512, 512, 256, 256, 256, 128, 128, 128]
        let rbKernels    = [ 3,   7,  11,   3,   7,  11,   3,   7,  11]
        for (ch, ks) in zip(rbChannelSeq, rbKernels) {
            rbs.append(HiFTResBlock(channels: ch, kernelSize: ks))
        }
        self.resblocks = rbs

        // 2. Call super.init()
        super.init()

        // 3. Initialize wrapped properties (@ModuleInfo)
        // Accessing these from nonisolated is allowed during init before escaping
        self._convPre.wrappedValue = Conv1d(
            inputChannels: 80, outputChannels: 512, kernelSize: 7, padding: 3)

        self._convPost.wrappedValue = Conv1d(
            inputChannels: postChannels, outputChannels: outputChannels, kernelSize: 7, padding: 3)

        self._f0Predictor.wrappedValue = ConvRNNF0Predictor()
        self._mSource.wrappedValue     = SourceModuleHnNSF()
    }

    // MARK: - Forward

    /// Generate audio from a mel spectrogram.
    /// - Parameters:
    ///   - mel: (B, T, 80) mel spectrogram
    ///   - refF0: optional reference F0 (unused — predicted internally)
    /// - Returns: (audioLen,) mono waveform (first batch item), float32
    func callAsFunction(_ mel: MLXArray, refF0: MLXArray? = nil) -> MLXArray {
        let _ = mel.shape[0]  // B - batch size
        let T = mel.shape[1]  // number of mel frames

        // ── 1. Predict F0 ────────────────────────────────────────────────────
        let f0 = f0Predictor(mel)  // (B, T, 1)

        // ── 2. Source signal ─────────────────────────────────────────────────
        let sourceSignal = mSource(f0, hopLen: melHop)  // (B, T*melHop, 1)

        // ── 3. Feature extraction (channels-first) ───────────────────────────
        // conv_pre expects NLC; we work in NCT (channels-first) inside.
        var x = convPre(mel)             // (B, T, 512) — NLC out
        x = x.transposed(0, 2, 1)       // → (B, 512, T) channels-first

        // Sum ResBlocks (channels-first)
        var feat = MLXArray.zeros(x.shape)
        for block in resblocks {
            // Each resblock may have its own channel size; guard mismatch
            if block.convs1.first != nil {
                feat = feat + block(x)
            }
        }
        x = feat / MLXArray(Float(max(resblocks.count, 1)))
        // x: (B, C, T)

        // ── 4. Post-conv → spectral features ─────────────────────────────────
        x = x.transposed(0, 2, 1)       // → (B, T, C) for Conv1d
        x = convPost(x)                  // (B, T, 18)
        x = x.transposed(0, 2, 1)       // → (B, 18, T)

        // ── 5. iSTFT synthesis ───────────────────────────────────────────────
        let audio = istftSynthesis(spec: x, source: sourceSignal, T: T)

        return audio.squeezed(axis: 0)  // (audioLen,)
    }

    // MARK: - iSTFT Synthesis

    /// Reconstruct waveform from spectral features using overlap-add iSTFT.
    ///
    /// - Parameters:
    ///   - spec:   (B, 18, T_frames) — 9 real + 9 imaginary spectral bins
    ///   - source: (B, T_frames * melHop, 1) — harmonic source signal
    ///   - T: number of mel frames
    /// - Returns: (B, audioLen) waveform
    private func istftSynthesis(spec: MLXArray, source: MLXArray, T: Int) -> MLXArray {
        let B      = spec.shape[0]
        let nFreqs = nFft / 2 + 1  // 11

        // Split spectral output into real and imaginary parts
        // spec: (B, 18, T) — first 9 = real components, last 9 = imag
        let real9 = spec[0..., 0..<9, 0...]   // (B, 9, T)
        let imag9 = spec[0..., 9..<18, 0...]  // (B, 9, T)

        // Zero-pad to nFreqs=11 bins
        let zeroPad = MLXArray.zeros([B, 2, T])
        let realFull = concatenated([real9, zeroPad], axis: 1)  // (B, 11, T)
        let imagFull = concatenated([imag9, zeroPad], axis: 1)  // (B, 11, T)

        // Transpose to (B, T, nFreqs) for frame-wise processing
        let realNLC = realFull.transposed(0, 2, 1)  // (B, T, 11)
        let imagNLC = imagFull.transposed(0, 2, 1)  // (B, T, 11)

        // Build complex-valued spectrum for iRFFT: amplitude * e^(j*phase)
        // MLX doesn't have a complex type; perform iFFT manually via cos/sin:
        // irfft(R + jI) frame-by-frame
        //
        // For each frame t, spectrum[t] is length nFreqs=11 (for nFft=20):
        //   - bin 0 (DC):   real only
        //   - bins 1..9:    complex
        //   - bin 10 (Nyq): real only
        //
        // We reconstruct each frame via: x[n] = sum_k { R_k*cos(2π*k*n/N) - I_k*sin(2π*k*n/N) }
        //   where N=nFft=20, n=0..19
        let N   = Float(nFft)
        let nOut = nFft  // samples per frame
        let nPositions = nOut

        // Build DFT cosine / sine basis matrices once: (nFreqs, nOut)
        var cosMatrix = [[Float]](repeating: [Float](repeating: 0, count: nPositions), count: nFreqs)
        var sinMatrix = [[Float]](repeating: [Float](repeating: 0, count: nPositions), count: nFreqs)
        for k in 0..<nFreqs {
            for n in 0..<nPositions {
                let angle = 2.0 * Float.pi * Float(k) * Float(n) / N
                cosMatrix[k][n] = cos(angle)
                sinMatrix[k][n] = -sin(angle)  // negative because iFFT sign convention
            }
        }
        let cosArr = MLXArray(cosMatrix.flatMap { $0 }).reshaped([nFreqs, nPositions])  // (11, 20)
        let sinArr = MLXArray(sinMatrix.flatMap { $0 }).reshaped([nFreqs, nPositions])  // (11, 20)

        // realNLC: (B, T, 11), imagNLC: (B, T, 11)
        // Synthesised frames: (B, T, 20)
        // frame_n = sum_k [ R_k * cos(k,n) + I_k * sin(k,n) ]
        //         = realNLC @ cosArr.T + imagNLC @ sinArr.T
        let synthFrames = matmul(realNLC, cosArr.T) + matmul(imagNLC, sinArr.T)
        // (B, T, nFft=20)

        // Overlap-add with hop length = 5 samples
        // audioLen covers all frames with overlap:
        //   start of last frame = (T-1)*hopLength, end = (T-1)*hopLength + nFft
        let audioLen = (T - 1) * hopLength + nFft

        // Build OLA output by constructing index arrays and scatter-add
        // Each of the T frames contributes nFft=20 samples at offsets t*hopLength
        // Efficient implementation: reshape and sum overlapping windows

        // Flatten synthFrames per batch and scatter-add
        // Process per batch item (B is typically 1 for inference)
        var audioBatch = [MLXArray]()
        for b in 0..<B {
            let frames = synthFrames[b]  // (T, nFft)
            // Build output buffer: (audioLen,)
            var audioOut = MLXArray.zeros([audioLen])

            // Scatter-add: for each frame index, add its samples
            // MLX doesn't have a direct scatter-add; use a loop over frames
            // This is acceptable for T ≈ 200-400 frames at 50fps
            for t in 0..<T {
                let frameStart = t * hopLength
                let frameEnd   = frameStart + nFft
                if frameEnd > audioLen { break }
                let frameData = frames[t]  // (nFft,)
                let existing  = audioOut[frameStart..<frameEnd]
                let updated   = existing + frameData
                // Reconstruct full array by concatenating slices
                let parts: [MLXArray]
                if frameStart > 0 {
                    parts = [audioOut[0..<frameStart], updated, audioOut[frameEnd..<audioLen]]
                } else {
                    parts = [updated, audioOut[frameEnd..<audioLen]]
                }
                audioOut = concatenated(parts, axis: 0)
            }

            // Modulate by source signal if shapes align
            // sourceSignal: (B, T*melHop, 1) → source for batch b: (T*melHop,)
            let srcLen = source.shape[1]
            if srcLen == audioLen {
                let srcB = source[b, 0..., 0]  // (srcLen,)
                audioOut = audioOut * srcB
            }

            audioBatch.append(audioOut.reshaped([1, audioLen]))
        }

        return concatenated(audioBatch, axis: 0)  // (B, audioLen)
    }
}
