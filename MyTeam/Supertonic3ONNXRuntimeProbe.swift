import Foundation
import OnnxRuntimeBindings

// MARK: - Supertonic3ONNXRuntimeProbe
// Round 254TTS-PROBE-FIX:
// Lightweight check for whether OnnxRuntimeBindings is linked and ORTEnv can be created.
//
// Scope: inference를 돌리지 않음. ORTEnv 생성만 시도.
// Call site: Probe 버튼 클릭 시만 호출. App launch 자동 호출 금지.
// Not product-ready / App Store-ready. TTS Lab / spike scope only.

enum Supertonic3ONNXRuntimeProbe {

    /// Returns true if OnnxRuntimeBindings is linked and ORTEnv can be created.
    /// This does NOT indicate inference success — model sessions are not created here.
    static var isRuntimeLinked: Bool {
        do {
            _ = try ORTEnv(loggingLevel: .warning)
            return true
        } catch {
            return false
        }
    }

    /// Short status note for probe display.
    static var statusNote: String {
        isRuntimeLinked
            ? "ONNX Runtime linked. 실제 합성은 ONNX 합성 실행으로 검증 필요."
            : "ONNX Runtime binding unavailable or not linked."
    }
}
