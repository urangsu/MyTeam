import Foundation

// MARK: - Supertonic3VoiceStyle
// Round 249TTS-SPIKE: Voice style loader for Supertonic3.
//
// Loads voice preset JSON files (e.g., F1.json, M3.json).
// JSON structure:
//   {
//     "style_ttl": { "data": [[[...]]], "dims": [1, 50, 256], "type": "float32" },
//     "style_dp":  { "data": [[[...]]], "dims": [1, 8, 16],  "type": "float32" },
//     "metadata":  {...}
//   }
//
// Python equivalent: Style object with .ttl ([1, 50, 256]) and .dp ([1, 8, 16])
//
// Both style tensors are used as-is (batch_size=1, no speed adjustment).

struct Supertonic3VoiceStyle: Sendable {

    // MARK: - Tensors

    /// style_ttl: flat Float32 array, shape [1, 50, 256] = 12800 elements
    let styleTTL: [Float]
    /// style_ttl shape: [1, 50, 256]
    let styleTTLShape: [Int]

    /// style_dp: flat Float32 array, shape [1, 8, 16] = 128 elements
    let styleDP: [Float]
    /// style_dp shape: [1, 8, 16]
    let styleDPShape: [Int]

    /// Preset name for diagnostics (e.g., "F1")
    let presetName: String

    // MARK: - Load

    /// Load voice style from JSON file.
    /// - Parameters:
    ///   - url: Path to the preset JSON file (e.g., ~/.cache/supertonic3/voice_styles/F1.json)
    ///   - preset: Preset name for diagnostics
    nonisolated static func load(from url: URL, preset: String) throws -> Supertonic3VoiceStyle {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json else {
            throw Supertonic3VoiceStyleError.invalidJSON("Root object must be a dictionary")
        }

        let ttl = try extractTensor(from: json, key: "style_ttl")
        let dp  = try extractTensor(from: json, key: "style_dp")

        return Supertonic3VoiceStyle(
            styleTTL: ttl.data,
            styleTTLShape: ttl.shape,
            styleDP: dp.data,
            styleDPShape: dp.shape,
            presetName: preset
        )
    }

    // MARK: - Private: JSON parsing

    private struct TensorEntry {
        let data: [Float]
        let shape: [Int]
    }

    nonisolated private static func extractTensor(from json: [String: Any], key: String) throws -> TensorEntry {
        guard let entry = json[key] as? [String: Any] else {
            throw Supertonic3VoiceStyleError.missingKey(key)
        }
        guard let rawDims = entry["dims"] as? [Any] else {
            throw Supertonic3VoiceStyleError.missingKey("\(key).dims")
        }
        let shape = rawDims.compactMap { n -> Int? in
            if let i = n as? Int { return i }
            if let d = n as? Double { return Int(d) }
            return nil
        }
        guard shape.count == rawDims.count else {
            throw Supertonic3VoiceStyleError.invalidShape("\(key).dims contains non-integer")
        }

        guard let rawData = entry["data"] else {
            throw Supertonic3VoiceStyleError.missingKey("\(key).data")
        }

        // Flatten nested array of arbitrary depth into [Float]
        let flat = try flattenToFloat(rawData)

        let expectedCount = shape.reduce(1, *)
        guard flat.count == expectedCount else {
            throw Supertonic3VoiceStyleError.shapeMismatch(
                key: key,
                expected: expectedCount,
                got: flat.count
            )
        }

        return TensorEntry(data: flat, shape: shape)
    }

    /// Recursively flatten nested JSON arrays to [Float].
    nonisolated private static func flattenToFloat(_ value: Any) throws -> [Float] {
        if let arr = value as? [Any] {
            var result: [Float] = []
            for element in arr {
                result.append(contentsOf: try flattenToFloat(element))
            }
            return result
        } else if let d = value as? Double {
            return [Float(d)]
        } else if let i = value as? Int {
            return [Float(i)]
        } else if let n = value as? NSNumber {
            return [n.floatValue]
        } else {
            throw Supertonic3VoiceStyleError.invalidDataElement("\(type(of: value))")
        }
    }
}

// MARK: - Errors

enum Supertonic3VoiceStyleError: Error, Sendable {
    case invalidJSON(String)
    case missingKey(String)
    case invalidShape(String)
    case shapeMismatch(key: String, expected: Int, got: Int)
    case invalidDataElement(String)
}
