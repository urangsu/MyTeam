import Foundation

// MARK: - SupertonicVoicePresetPolicy
// Round 256TTS-OFFICIAL-ENGINE: 캐릭터/에이전트별 Supertonic3 voice preset 매핑.
//
// 실제 AgentWindowManager.allAvailableAgents ID 기반 (agent_1 ~ agent_11).
// Preset 범위: M1-M5 (남성), F1-F5 (여성).
// unknown agentID → Supertonic3TTSConfig.selectedVoicePreset (사용자 설정 기본값).
// voice preset fallback은 TTS 폴백이 아님 — preset 수준 default만 적용.

enum SupertonicVoicePresetPolicy {

    /// Returns the voice preset for the given agentID.
    /// Falls back to user-selected preset for unknown agents.
    static func preset(for agentID: String?) -> String {
        switch agentID {
        case "agent_1":   return "M1"  // 레오 — 비즈니스 전략가 (남성, 안정적)
        case "agent_2":   return "F1"  // 루나 — 마케터/콘텐츠 기획 (여성, 밝음)
        case "agent_3":   return "F3"  // 모코 — 프로젝트 매니저 (여성, 차분)
        case "agent_4":   return "F4"  // 핀 — UI 디자이너 (여성, 경쾌)
        case "agent_5":   return "F2"  // 치코 — 문서·할일 정리 (여성, 친근)
        case "agent_6":   return "M3"  // 렉스 — 법률 전문가 (남성, 신중)
        case "agent_7":   return "M2"  // 케이 — 보안/데이터 전문가 (남성, 분석적)
        case "agent_8":   return "M4"  // 래키 — 백엔드 개발자 (남성, 집중)
        case "agent_9":   return "F5"  // 폴라 — 세일즈/BD (여성, 설득력)
        case "agent_10":  return "F3"  // 몽몽 — 고객 서비스 (여성, 따뜻)
        case "agent_11":  return "M5"  // 올리버 — QA 엔지니어 (남성, 꼼꼼)
        default:
            // Unknown agent or nil → user's selected preset
            return Supertonic3TTSConfig.selectedVoicePreset
        }
    }
}
