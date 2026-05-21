import Foundation

// MARK: - S3WavWriter
// Round 249TTS-RUNTIME: Writes Supertonic3 synthesis output to a WAV file.
// Output location: ~/Desktop/supertonic3_spike_{tag}_{timestamp}.wav
// PCM encoding: 16-bit signed, mono, little-endian (standard WAV).
// Float32 samples → Int16 with clamp.
// Spike scope only — not connected to production audio pipeline.

enum S3WavWriter {

    /// Writes `samples` (Float32 PCM, range –1.0…1.0) as a 16-bit mono WAV file.
    /// - Returns: The absolute path of the written file, or nil on failure.
    @discardableResult
    static func write(samples: [Float], sampleRate: Int, tag: String) -> String? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename  = "supertonic3_spike_\(tag)_\(timestamp).wav"
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent(filename)

        let int16Samples = samples.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }

        guard let data = buildWAV(int16Samples: int16Samples, sampleRate: sampleRate) else {
            return nil
        }

        do {
            try data.write(to: url)
            return url.path
        } catch {
            return nil
        }
    }

    // MARK: - WAV builder

    private static func buildWAV(int16Samples: [Int16], sampleRate: Int) -> Data? {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate   = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize   = UInt32(int16Samples.count * MemoryLayout<Int16>.stride)
        let chunkSize  = 36 + dataSize  // RIFF chunk size

        var d = Data()

        // RIFF header
        d.append(contentsOf: "RIFF".utf8)
        d.appendLE32(chunkSize)
        d.append(contentsOf: "WAVE".utf8)

        // fmt  sub-chunk
        d.append(contentsOf: "fmt ".utf8)
        d.appendLE32(16)             // sub-chunk size (PCM)
        d.appendLE16(1)              // AudioFormat = PCM
        d.appendLE16(numChannels)
        d.appendLE32(UInt32(sampleRate))
        d.appendLE32(byteRate)
        d.appendLE16(blockAlign)
        d.appendLE16(bitsPerSample)

        // data sub-chunk
        d.append(contentsOf: "data".utf8)
        d.appendLE32(dataSize)
        int16Samples.forEach { d.appendLE16(UInt16(bitPattern: $0)) }

        return d
    }
}

// MARK: - Data extension helpers

private extension Data {
    mutating func appendLE32(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func appendLE16(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
