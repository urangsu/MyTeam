import Foundation

// MARK: - ONNX Runtime Boundary Protocol

enum ONNXRuntimeAvailability: String, Codable, Sendable {
    case unavailable
    case packageMissing
    case packagePresent
    case runtimeReady
}

// MARK: - ONNX Runtime Session Protocol

protocol ONNXRuntimeSessionProtocol: Sendable {
    var modelName: String { get }
}

struct UnavailableONNXRuntimeSession: ONNXRuntimeSessionProtocol {
    let modelName: String
}

// MARK: - ONNX Runtime Adapter Protocol

protocol ONNXRuntimeAdapterProtocol: Sendable {
    func availability() -> ONNXRuntimeAvailability
    func loadSession(modelURL: URL, name: String) async throws -> ONNXRuntimeSessionProtocol
    func run(session: ONNXRuntimeSessionProtocol, inputs: Supertonic3TensorInputs) async throws -> Supertonic3TensorOutputs
}

// MARK: - Unavailable Adapter (Cloud/No Runtime)

struct ONNXRuntimeUnavailableAdapter: ONNXRuntimeAdapterProtocol {
    func availability() -> ONNXRuntimeAvailability {
        .unavailable
    }

    func loadSession(modelURL: URL, name: String) async throws -> ONNXRuntimeSessionProtocol {
        throw TTSProviderError.missingRuntime
    }

    func run(session: ONNXRuntimeSessionProtocol, inputs: Supertonic3TensorInputs) async throws -> Supertonic3TensorOutputs {
        throw TTSProviderError.missingRuntime
    }
}

// MARK: - Error Types

enum TTSProviderError: LocalizedError {
    case missingRuntime
    case notEnabled
    case missingModel
    case invalidVoicePreset(String)
    case inferenceFailure(String)
    case audioConversionFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingRuntime:
            return "ONNX Runtime not available on this system"
        case .notEnabled:
            return "TTS provider not enabled"
        case .missingModel:
            return "Required model files not found"
        case .invalidVoicePreset(let preset):
            return "Invalid voice preset: \(preset)"
        case .inferenceFailure(let msg):
            return "Inference failed: \(msg)"
        case .audioConversionFailure(let msg):
            return "Audio conversion failed: \(msg)"
        }
    }
}
