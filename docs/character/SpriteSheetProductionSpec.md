# SpriteSheet Production Spec

**Updated**: 2026-05-17 (Round 231A)  
**Source of truth**: `MyTeam/CharacterSpriteScene.swift` — `enum AnimationState`

---

## Runtime Architecture

| Component | File | Role |
|-----------|------|------|
| `AnimationState` | `CharacterSpriteScene.swift` | 상태 enum (모든 케이스 정의) |
| `SpriteAgentView` | `SpriteAgentView.swift` | SwiftUI 뷰, 상태를 scene에 전달 |
| `CharacterSpriteScene` | `CharacterSpriteScene.swift` | SpriteKit scene, PNG 시퀀스 로더 |
| `CharacterDialogues` | `CharacterDialogues.swift` | 캐릭터별 대사 딕셔너리 |
| `AgentSeatView` | `AgentSeatView.swift` | 좌석 레이아웃, agentEmotions 바인딩 |

---

## File Convention

```
Sprites/{characterID}/{characterID}_{state}_{index}.png
```

- `{characterID}`: 캐릭터 이름 (예: `치코`, `레오`, `루나`, `렉스`)
- `{state}`: `AnimationState.rawValue` 그대로 사용
- `{index}`: 1부터 시작하는 프레임 번호 (예: `01`, `02`, `03`)

### 예시
```
Sprites/치코/치코_typing_01.png
Sprites/치코/치코_typing_02.png
Sprites/치코/치코_joy_01.png
Sprites/치코/치코_greeting_01.png
```

---

## Chiko (치코) — Runtime Required States

치코: `spriteName: "치코"`, `fallbackImageName: "치코_profile"`.

### Runtime-required (반드시 스프라이트 필요)

| AnimationState | rawValue | 용도 |
|----------------|----------|------|
| `.typing` | `"typing"` | 기본 업무 상태 ★ 최우선 |
| `.idle` | `"idle"` | 대기 상태 |
| `.speaking` | `"speaking"` | 말하는 중 |
| `.greeting` | `"greeting"` | 인사 (workroomOpened reaction) |
| `.joy` | `"joy"` | 완료/성공 (documentCreated reaction) |
| `.backToWork` | `"backwork"` | 업무 복귀 (artifactReuse reaction) |

### Secondary (있으면 좋음)

| AnimationState | rawValue | 용도 |
|----------------|----------|------|
| `.resting` | `"resting"` | 휴식 / sleeping fallback |
| `.agree` | `"agree"` | 긍정 반응 |
| `.confused` | `"confused"` | 오류/모호한 입력 |
| `.sad` | `"sad"` | 실패 |
| `.clockIn` | `"clockin"` | 출근 |

### Fallback-only (파일 불필요, 코드 호환용)

실제 AnimationState enum에 정의되어 있으나 스프라이트 파일 없이도 fallback으로 처리됨.

| AnimationState | rawValue | Fallback 대상 |
|----------------|----------|---------------|
| `.thinking` | `"thinking"` | → `idle` |
| `.praise` | `"praise"` | → `agree` |
| `.sleeping` | `"sleeping"` | → `resting` |
| `.disagree` | `"disagree"` | → `angry` |
| `.look` | `"look"` | → `idle` |
| `.lookLeft` | `"look_left"` | → `look` → `idle` |
| `.lookRight` | `"look_right"` | → `look` → `idle` |

---

## Other Characters (레오, 루나, 렉스)

동일 파일 규칙 적용. 스프라이트 없으면 캐릭터별 `fallbackImageName` 사용.

Release DLC 캐릭터 스프라이트는 앱 번들에 포함하지 않는다.

---

## CharacterReaction → AnimationState 매핑 (Round 231A)

| WorkroomCharacterEvent | AnimationState | rawValue |
|------------------------|----------------|----------|
| `workroomOpened` | `.greeting` | `"greeting"` |
| `workflowStarted` (universalDocument) | `.typing` | `"typing"` |
| `workflowStarted` (기타) | `.thinking` | `"thinking"` (→ idle fallback) |
| `documentCreated` | `.joy` | `"joy"` |
| `artifactReuseRequested` | `.backToWork` | `"backwork"` |
| `multiRoomSwitched` | `.idle` | `"idle"` |

---

## Production Pipeline

1. **디자이너**: 각 캐릭터 × Runtime-required 상태별 PNG 시퀀스 제작
2. **파일명**: 규칙 준수 (`{characterID}_{state}_{index}.png`)
3. **Xcode**: `Sprites/` 폴더를 Resources group에 추가
4. **CharacterSpriteScene**: 자동으로 해당 경로에서 로드 (코드 변경 불필요)
5. **QA**: `AnimationState.allCases`로 모든 상태 순회 테스트

---

## Status (2026-05-17)

| 항목 | 상태 |
|------|------|
| 치코 Runtime-required 스프라이트 | ⏳ 디자인팀 대기 |
| CharacterReactionEngine 구현 | ✅ Round 231A 완료 |
| AnimationState → Reaction 매핑 | ✅ 5개 이벤트 완료 |
| SpriteKit 로더 | ✅ 기존 코드 유지 (변경 없음) |
| agentEmotions 연결 | ✅ CharacterReactionEventSink 완료 |
