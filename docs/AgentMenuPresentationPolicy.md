# Agent Menu Presentation Policy

**Version:** Round 241C  
**Date:** 2026-05-20

---

## Rule

에이전트 액션 메뉴(대화/추가 설정/교체/팀장 설정)는 패널 또는 창 경계에 잘리면 안 된다.

---

## 승인된 구현 방식

### A) SwiftUI contextMenu (권장)

```swift
AgentSeatView(...)
    .contextMenu {
        Button { manager.showChat(for: agent) } label: {
            Label("대화", systemImage: "message")
        }
        Button { manager.showSwapWindow(replaceIndex: index) } label: {
            Label("교체", systemImage: "arrow.triangle.2.circlepath")
        }
        // ...
    }
```

- 시스템이 위치를 자동 보정 → 창 경계 잘림 없음
- 우클릭 또는 길게 누르기로 작동
- macOS 네이티브 메뉴 스타일

### B) Root-level ZStack overlay (대안)

- `TeamTableView.body` 최상위 `ZStack`에 메뉴 뷰 배치
- `GeometryReader` 또는 `PreferenceKey`로 좌표 전달
- 에이전트 cell 내부 `.overlay()` 사용 금지

---

## 금지 패턴

```swift
// ❌ Cell 내부 overlay + offset → 패널 경계 clipping
AgentSeatView(...)
    .overlay(
        AgentMenuPopupView(isShowing: ...)
            .offset(x: 100, y: -80)  // 부모 bounds 밖으로 나가서 잘림
    )
```

---

## 현재 구현 (Round 241C)

`TeamTableView`에서 `AgentMenuPopupView` 커스텀 overlay 제거.  
`.contextMenu { }` 로 교체 완료.

메뉴 항목:
- 대화 (`message`)
- 추가 설정 (`slider.horizontal.3`)
- 교체 (`arrow.triangle.2.circlepath`)
- 팀장 설정 / 팀장 해제 (`crown` / `crown.fill`)
