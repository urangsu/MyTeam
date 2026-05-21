import Foundation

// Round 248TTS-A: Runtime boundary for ONNX integration
// Cloud: unavailable, throws missingRuntime
// Mac local (249TTS): OrtEnvironment + OrtSession + OrtValue 연결

enum ONNXRuntimeAvailability: String, Codable, Sendable {
    case unavailable       // No ONNX package
    case packageMissing    // onnxruntime-swift not in SPM
    case packagePresent    // SPM registered but runtime unavailable
    case runtimeReady      // OrtEnvironment initialized, can create sessions
}

protocol ONNXRuntimeSessionProtocol: Sendable {
    var modelName: String { get }
}

struct UnavailableONNXRuntimeSession: ONNXRuntimeSessionProtocol {
    let modelName: String
}

protocol ONNXRuntimeAdapterProtocol: Sendable {
    func availability() -> ONNXRuntimeAvailability
    func loadSession(modelURL: URL, name: String) async throws -> ONNXRuntimeSessionProtocol
    func run(session: ONNXRuntimeSessionProtocol, inputs: Supertonic3TensorInputs) async throws -> Supertonic3TensorOutputs
}

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

// Round 249TTS: Mac local implementation
// struct ONNXRuntimeLiveAdapter: ONNXRuntimeAdapterProtocol {
//     private let ortEnvironment: OrtEnvironment // import onnxruntime_objc
//     ...
// }
