import Foundation
import Combine
import AVFoundation
import Speech

// MARK: - PermissionsManager
// TCC(Transparency, Consent and Control) 권한 요청 전담.
// UI 흐름을 차단하는 비동기 권한 요청을 이 actor 안에 완전히 격리한다.
// AudioCaptureService는 이 클래스의 결과를 받아 엔진을 시작한다.
actor PermissionsManager {
    static let shared = PermissionsManager()
    private init() {}

    // MARK: - 마이크 하드웨어 존재 여부
    nonisolated var hasMicrophone: Bool {
        AVCaptureDevice.default(for: .audio) != nil
    }

    // MARK: - 마이크 권한 요청 (TCC Layer 1)
    func requestMicrophoneAccess() async -> Bool {
        guard hasMicrophone else {
            print("[PermissionsManager] ❌ 연결된 마이크 없음.")
            return false
        }
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted {
                    print("[PermissionsManager] ❌ 마이크 권한 거부됨. 시스템 설정 > 개인정보 보호 확인.")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 음성 인식 권한 요청 (TCC Layer 2)
    func requestSpeechRecognitionAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let granted = status == .authorized
                if !granted {
                    print("[PermissionsManager] ❌ 음성 인식 권한 없음. 시스템 환경설정 확인.")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 순서대로 양쪽 모두 요청 (단축 호출)
    func requestAllAudioPermissions() async -> Bool {
        let mic = await requestMicrophoneAccess()
        guard mic else { return false }
        return await requestSpeechRecognitionAccess()
    }
}
