import Foundation
import MLX
import MLXRandom
import Dispatch

// T3 LlamaModel 래퍼 (추후 구현)
public class MLXModel {
    public init() {}
}

actor MLXModelManager {
    static let shared = MLXModelManager()
    
    // FP16 원본 가중치. OS가 죽이려 들지 않는 이상 절대 메모리에서 내려가지 않음.
    private var t3Model: MLXModel?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    private init() {
        Task {
            await setupMemoryPressureMonitor()
        }
    }
    
    /// 상시 대기 포맷(FP16)으로 T3 모델 적재
    func loadModelIfNeeded() async throws -> MLXModel {
        if let model = t3Model {
            return model // 즉시 캐시 히트 (Cold-start 없음)
        }
        
        print("[MLXModelManager] 🔥 VRAM 리미터 해제. Float16 고해상도 가중치 통합 메모리 적재 시작...")
        
        // Quantization 없이 순정(FP16)으로 즉각 로드 (2~3GB 이상 상시 점유)
        // 실제 구현부: let loadedModel = try await MLXModel.load(url: weightsURL)
        let loadedModel = MLXModel() // 뼈대 Mock
        
        self.t3Model = loadedModel
        print("[MLXModelManager] 🚀 FP16 모델 상시 대기(Warm-Standby) 완료.")
        
        return loadedModel
    }
    
    /// 오직 macOS 시스템이 붕괴 직전(Critical)일 때만 호흡기 유지용으로 Unload
    private func setupMemoryPressureMonitor() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.critical], queue: .main)
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task {
                await self.emergencyUnload()
            }
        }
        memoryPressureSource?.resume()
    }
    
    private func emergencyUnload() {
        guard t3Model != nil else { return }
        print("[MLXModelManager] 🚨 시스템 Critical 메모리 압박 감지! 모델 강제 퇴거 (OS 보호)")
        t3Model = nil
    }
}
