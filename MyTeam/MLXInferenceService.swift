import Foundation
import AVFoundation

actor MLXInferenceService {
    static let shared = MLXInferenceService()
    private init() {}
    
    /// AsyncStream을 통한 우아한 C-Level 스트림 브릿지 (백프레셔 버퍼 제한 적용)
    func generateTTSStream(
        text: String,
        characterName: String
    ) -> AsyncStream<Data> {
        
        // 백프레셔 통제: 오디오 엔진이 처리 가능한 적정량(최대 5청크)만 큐에 홀딩하여 메모리 폭발(OOM) 원천 차단
        return AsyncStream(Data.self, bufferingPolicy: .bufferingNewest(5)) { continuation in
            // Heavy Compute 무조건 백그라운드로 강력 격리 (UI 60fps 보장)
            Task.detached(priority: .userInitiated) {
                
                // 1. FP16 모델 확보 (딜레이 0초)
                guard let model = try? await MLXModelManager.shared.loadModelIfNeeded() else {
                    print("[MLXInferenceService] ❌ 가중치 로드 실패")
                    continuation.finish()
                    return
                }
                
                print("[MLXInferenceService] 🧠 Real-time Inference 시작 (텍스트: \(text.prefix(10))...)")
                
                // 2. 가상의 MLX AR Decode C루프
                // 모델이 뱉어낸 Float32 출력물이 곧바로 PCM Data로 변환됨
                for _ in 0..<15 {
                    
                    // 끼어들기(Barge-in)나 뷰 파괴 등 외부 취소 발생 시 GPU 연산 스톱
                    if Task.isCancelled {
                        print("[MLXInferenceService] 🛑 스트림 중단 (Cancelled)")
                        break
                    }
                    
                    // C-레벨에서 추론된 1 청크 추출
                    let pcmData = MLXInferenceService.generateDummyPCMDataChunk()
                    
                    // Task { await.. } 낭비 없이 AsyncStream 하수구로 바로 밀어넣기. 
                    // 버퍼가 꽉 찼으면 가장 오래된/새거운 데이터를 버림(백프레셔 작동)
                    continuation.yield(pcmData)
                }
                
                // 3. 문장 전송 종료 선언
                continuation.finish()
                print("[MLXInferenceService] ✅ 스트리밍 연산 및 송출 완료.")
            }
        }
    }
    
    // Dummy PCM Data Generator
    private static func generateDummyPCMDataChunk() -> Data {
        let sampleRate = 24000
        let duration = 0.05 // 아주 짧은 50ms 단위 토큰 렌더링
        let sampleCount = Int(Double(sampleRate) * duration)
        var pcmBuffer = [Float32](repeating: 0.1, count: sampleCount)
        return Data(bytes: &pcmBuffer, count: sampleCount * 4)
    }
}
