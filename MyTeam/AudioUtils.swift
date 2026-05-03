// AudioUtils.swift
import Foundation
import MLX
import MLXNN
import MLXRandom
import MLXFFT

// MARK: - Hann Window

/// Periodic Hann window: w[n] = 0.5 * (1 - cos(2*pi*n / size))
/// Uses `size` (not size-1) in the denominator for a periodic window.
nonisolated func hannWindow(size: Int) -> MLXArray {
    let indices = MLXArray(Array(0..<size).map { Float($0) })
    let twoPiOverN = Float(2.0 * Double.pi) / Float(size)
    return 0.5 * (1.0 - MLX.cos(indices * twoPiOverN))
}

// MARK: - Mel Filterbank

/// Returns a mel filterbank matrix of shape (nFft/2+1, nMels).
/// Uses HTK-style mel scale: mel = 2595 * log10(1 + f/700)
/// Filters are area-normalized (Slaney-style).
nonisolated func melFilterbank(
    sampleRate: Int,
    nFft: Int,
    nMels: Int,
    fMin: Float,
    fMax: Float
) -> MLXArray {
    let numBins = nFft / 2 + 1
    let melMin = 2595.0 * log10(1.0 + Double(fMin) / 700.0)
    let melMax = 2595.0 * log10(1.0 + Double(fMax) / 700.0)

    // nMels+2 linearly-spaced mel points
    let melPoints: [Double] = (0..<(nMels + 2)).map { i in
        melMin + Double(i) * (melMax - melMin) / Double(nMels + 1)
    }

    // Convert mel points back to Hz
    let hzPoints: [Double] = melPoints.map { mel in
        700.0 * (pow(10.0, mel / 2595.0) - 1.0)
    }

    // Map Hz to FFT bin indices
    let freqResolution = Double(sampleRate) / Double(nFft)
    let binIndices: [Double] = hzPoints.map { hz in
        floor(hz / freqResolution)
    }

    // Build filterbank row-by-row: (numBins, nMels)
    var filterbank = [[Float]](repeating: [Float](repeating: 0.0, count: nMels), count: numBins)

    for m in 0..<nMels {
        let fLow = binIndices[m]
        let fCenter = binIndices[m + 1]
        let fHigh = binIndices[m + 2]

        // Slaney area normalization factor: 2 / (hz_high - hz_low)
        let normFactor = Float(2.0 / (hzPoints[m + 2] - hzPoints[m]))

        for k in 0..<numBins {
            let kf = Double(k)
            if kf >= fLow && kf <= fCenter {
                // Rising slope
                if fCenter > fLow {
                    filterbank[k][m] = normFactor * Float((kf - fLow) / (fCenter - fLow))
                }
            } else if kf > fCenter && kf <= fHigh {
                // Falling slope
                if fHigh > fCenter {
                    filterbank[k][m] = normFactor * Float((fHigh - kf) / (fHigh - fCenter))
                }
            }
        }
    }

    // Flatten to 1D and wrap in MLXArray with shape (numBins, nMels)
    let flat = filterbank.flatMap { $0 }
    return MLXArray(flat, [numBins, nMels])
}

// MARK: - STFT

/// Computes Short-Time Fourier Transform.
/// Returns complex array of shape (T_frames, nFft/2+1).
/// Center-padding: pads signal by nFft//2 on each side (reflect padding).
nonisolated func computeSTFT(
    wav: MLXArray,
    nFft: Int,
    hopLength: Int,
    winLength: Int,
    center: Bool = true
) -> MLXArray {
    // Ensure 1D
    let signal: MLXArray
    if wav.ndim > 1 {
        signal = wav.reshaped([-1])
    } else {
        signal = wav
    }

    let window = hannWindow(size: winLength)
    // Pad window to nFft size if winLength < nFft
    let paddedWindow: MLXArray
    if winLength < nFft {
        let leftPad = (nFft - winLength) / 2
        let rightPad = nFft - winLength - leftPad
        let leftZeros = zeros([leftPad])
        let rightZeros = zeros([rightPad])
        paddedWindow = concatenated([leftZeros, window, rightZeros], axis: 0)
    } else {
        paddedWindow = window
    }

    // Optionally center-pad the signal with reflect padding
    let paddedSignal: MLXArray
    if center {
        let padSize = nFft / 2
        let sigLen0 = signal.dim(0)
        // Left reflect: indices [padSize, padSize-1, ..., 1]
        let leftIdx = MLXArray((1...padSize).reversed().map { Int32($0) })
        let leftReflect = MLX.take(signal, leftIdx, axis: 0)
        // Right reflect: indices [sigLen-2, sigLen-3, ..., sigLen-padSize-1]
        let rightIdx = MLXArray(((sigLen0 - 1 - padSize)..<(sigLen0 - 1)).reversed().map { Int32($0) })
        let rightReflect = MLX.take(signal, rightIdx, axis: 0)
        paddedSignal = concatenated([leftReflect, signal, rightReflect], axis: 0)
    } else {
        paddedSignal = signal
    }

    let sigLen = paddedSignal.dim(0)
    // Number of frames
    let numFrames = (sigLen - nFft) / hopLength + 1

    // Extract frames and apply window
    // Build frames: shape (numFrames, nFft)
    var frames = [MLXArray]()
    frames.reserveCapacity(numFrames)
    for i in 0..<numFrames {
        let start = i * hopLength
        let frame = paddedSignal[start..<(start + nFft)] * paddedWindow
        frames.append(frame.reshaped([1, nFft]))
    }
    let framesMatrix = concatenated(frames, axis: 0)  // (numFrames, nFft)

    // Compute rfft along axis 1
    let spectrogram = MLXFFT.rfft(framesMatrix, axis: 1)  // (numFrames, nFft/2+1) complex
    return spectrogram
}

// MARK: - VoiceEncoder Mel Spectrogram (40-bin, 16kHz)

#if false  // [DEAD CODE] VoiceEncoder / ChatterboxPipeline 전용 — 현재 파이프라인에서 미사용
nonisolated func voiceEncMelSpectrogram(wav: MLXArray) -> MLXArray {
    let sr = VoiceEncConfig.sampleRate
    let nFft = VoiceEncConfig.nFft       // 400
    let hop = VoiceEncConfig.hopSize     // 160
    let win = VoiceEncConfig.winSize     // 400
    let nMels = VoiceEncConfig.numMels   // 40
    let fMin = VoiceEncConfig.fmin       // 0
    let fMax = VoiceEncConfig.fmax       // 8000

    // STFT: (T, nFft/2+1) complex
    let stft = computeSTFT(wav: wav, nFft: nFft, hopLength: hop, winLength: win, center: true)

    // Magnitude squared (power spectrum)
    let magnitudes = MLX.abs(stft)               // (T, nFft/2+1) real
    let power = magnitudes * magnitudes           // element-wise square

    // Mel filterbank: (nFft/2+1, nMels)
    let filterbank = melFilterbank(sampleRate: sr, nFft: nFft, nMels: nMels, fMin: fMin, fMax: fMax)

    // Apply filterbank: (T, nFft/2+1) @ (nFft/2+1, nMels) → (T, nMels)
    let melSpec = matmul(power, filterbank)  // (T, nMels)

    // Transpose to (nMels, T)
    return melSpec.transposed(1, 0)
}

// MARK: - S3Gen Mel Spectrogram (80-bin, 24kHz)

/// Computes 80-bin mel spectrogram for HiFTGenerator reference.
/// Input: 1D wav array sampled at 24kHz.
/// Output: (T_frames, 80) — no center padding.
nonisolated func s3genMelSpectrogram(wav: MLXArray) -> MLXArray {
    let sr = AudioConstants.s3genSR  // 24000
    let nFft = 1920
    let hop = 480
    let win = 1920
    let nMels = 80
    let fMin: Float = 0.0
    let fMax: Float = 8000.0

    // STFT without center padding: (T, nFft/2+1) complex
    let stft = computeSTFT(wav: wav, nFft: nFft, hopLength: hop, winLength: win, center: false)

    // Magnitude (not power) → use magnitude for HiFTGenerator convention
    let magnitudes = MLX.abs(stft)  // (T, nFft/2+1) real

    // Mel filterbank: (nFft/2+1, nMels)
    let filterbank = melFilterbank(sampleRate: sr, nFft: nFft, nMels: nMels, fMin: fMin, fMax: fMax)

    // Apply filterbank: (T, nFft/2+1) @ (nFft/2+1, nMels) → (T, nMels=80)
    let melSpec = matmul(magnitudes, filterbank)

    // Already (T, 80) — return as-is
    return melSpec
}
#endif
