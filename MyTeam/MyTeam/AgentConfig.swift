import SwiftUI

// MARK: - AgentConfig (AgentWindowManager에서 분리)
// AgentWindowManager.AgentConfig 타입 유지 — 기존 참조 코드 변경 불필요

extension AgentWindowManager {

    struct AgentConfig: Identifiable {
        let id: String
        let name: String
        let role: String         // 예: "프로젝트 매니저" (UI 상단용)
        let emoji: String        // 평상시 이모지 (스프라이트 없을 때 폴백)
        let color: Color
        let isPremium: Bool      // 교체 창 UI용 (무료/프리미엄 표시)
        var status: String       // 현재 상태

        // ── 스프라이트 애니메이션 ──
        // Assets에 등록된 PNG 시퀀스 파일명 접두사
        // nil이면 이모지로 폴백합니다.
        // 예: "sloth" → sloth_idle_001.png, sloth_joy_001.png ...
        let spriteName: String?

        // ── 개인별 드래그 반응 ──
        let dragEmoji: String    // 드래그 중 이모지 (스프라이트 없을 때 폴백)
        let dragRotation: Double // 기울기 각도
        let dragSoundName: String
        let dropSoundName: String
    }

}
