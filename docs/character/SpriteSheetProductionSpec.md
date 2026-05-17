# SpriteSheet Production Spec

**Updated**: 2026-05-17 (Round 234)
**Source of truth**: `MyTeam/CharacterSpriteScene.swift` — `enum AnimationState`
**Asset Policy**: `MyTeam/CharacterSpriteAssetPolicy.swift` — 런타임 검증
**Manifest**: `MyTeam/CharacterSpriteManifest.swift` — requiredStates / optionalStates
**Validator**: `scripts/validate_sprites.sh` — CI/수동 실행, macOS NFD 대응

---

## Runtime Architecture

| Component | File | Role |
|-----------|------|------|
| `AnimationState` | `CharacterSpriteScene.swift` | 상태 enum (모든 케이스 정의) |
| `SpriteAgentView` | `SpriteAgentView.swift` | SwiftUI 뷰, 상태를 scene에 전달 |
| `CharacterSpriteScene` | `CharacterSpriteScene.swift` | SpriteKit scene, PNG 시퀀스 로더 |
| `CharacterDialogues` | `CharacterDialogues.swift` | 캐릭터별 대사 딕셔너리 |
| `AgentSeatView` | `AgentSeatView.swift` | 좌석 레이아웃, agentEmotions 바인딩 |
| `CharacterReactionEventSink` | `CharacterReactionEventSink.swift` | Workroom 이벤트 → agentEmotions 브리지 |

---

## File Convention

```
Sprites/{characterID}/{characterID}_{state}_{index}.png
```

- `{characterID}`: 캐릭터 이름 (예: `치코`, `레오`, `루나`, `렉스`)
- `{state}`: `AnimationState.rawValue` 그대로 사용
- `{index}`: 3자리 숫자 (예: `001`, `002`, `003`)

### 예시
```
Sprites/치코/치코_typing_001.png
Sprites/치코/치코_typing_002.png
Sprites/치코/치코_joy_001.png
Sprites/치코/치코_greeting_001.png
```

---

## AnimationState 전체 목록 (CharacterSpriteScene.swift 기준)

### 핵심 루프 모션
| AnimationState | rawValue | 용도 |
|----------------|----------|------|
| `.idle` | `"idle"` | 대기 (앉아있는 앵커) |
| `.typing` | `"typing"` | 업무 중 ★ 기본 상태 |
| `.idleLoop` | `"idle_loop"` | 아이들 루프 (있으면 사용) |
| `.speaking` | `"speaking"` | 말하는 중 |
| `.resting` | `"resting"` | 휴식 (노트북 닫힘, 수면 통합) |

### 감정/반응 모션
| AnimationState | rawValue | 용도 |
|----------------|----------|------|
| `.joy` | `"joy"` | 기쁨 (어깨 으쓱) |
| `.sad` | `"sad"` | 슬픔 (눈물 맺힘) |
| `.agree` | `"agree"` | 긍정대답 + 칭찬 흡수 |
| `.angry` | `"angry"` | 화남 |
| `.confused` | `"confused"` | 갸우뚱 (disagree 대체) |

### 인터랙션 모션
| AnimationState | rawValue | 용도 |
|----------------|----------|------|
| `.greeting` | `"greeting"` | 인사 (목례) |
| `.drag` | `"drag"` | 드래그 중 |
| `.lifted` | `"lifted"` | 들려짐 |
| `.dropped` | `"drop"` | 떨어짐 (구 파일명 유지) |
| `.lowering` | `"lowering"` | 내려감 |
| `.landing` | `"landing"` | 착지 |

### 업무 흐름 모션
| AnimationState | rawValue | 용도 |
|----------------|----------|------|
| `.clockIn` | `"clockin"` | 출근 (노트북 열기) |
| `.clockOut` | `"clockout"` | 퇴근 |
| `.backToWork` | `"backwork"` | 업무 복귀 |
| `.returnToTyping` | `"typing_return"` | 타자 복귀 |

### 폴백 전용 케이스 (파일 불필요, 코드 호환용)
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

## Chiko (치코) v1 — Runtime Required

치코: `spriteName: "치코"`, `fallbackImageName: "치코_profile"`

### v1 필수 (스프라이트 파일 반드시 필요)

| AnimationState | rawValue | 용도 |
|----------------|----------|------|
| `.idle` | `"idle"` | 대기 ★ |
| `.typing` | `"typing"` | 업무 중 ★ |
| `.speaking` | `"speaking"` | 말하는 중 |
| `.greeting` | `"greeting"` | 워크룸 오픈 인사 |
| `.joy` | `"joy"` | artifact 생성 완료 |
| `.sad` | `"sad"` | 실패/오류 |
| `.confused` | `"confused"` | 검증 경고/애매함 |
| `.drag` | `"drag"` | 사용자가 집어 듦 |
| `.landing` | `"landing"` | 착지 |
| `.clockIn` | `"clockin"` | 출근/앱 오픈 |
| `.backToWork` | `"backwork"` | 작업 재개 |

### v1 선택 (있으면 사용, 없으면 fallback)

| AnimationState | rawValue | 폴백 |
|----------------|----------|------|
| `.thinking` | `"thinking"` | → idle |
| `.agree` | `"agree"` | optional |
| `.resting` | `"resting"` | optional |
| `.sleeping` | `"sleeping"` | → resting |
| `.look` | `"look"` | → idle |

---

## CharacterReaction → AnimationState 매핑 (Round 232)

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

1. **디자이너**: 각 캐릭터 × v1 필수 상태별 PNG 시퀀스 제작
2. **파일명**: 규칙 준수 (`{characterID}_{rawValue}_{index:3}.png`)
3. **Xcode**: `Sprites/` 폴더를 Resources group에 추가
4. **CharacterSpriteScene**: 자동으로 해당 경로에서 로드 (코드 변경 불필요)
5. **QA**: `AnimationState.allCases`로 모든 상태 순회 테스트

---

## Status (2026-05-17)

| 항목 | 상태 |
|------|------|
| 치코 v1 필수 스프라이트 (런타임) | ✅ 674 PNG 확인 (13개 required state 포함) |
| Sprites/ intake 폴더 | ✅ Round 234 scaffold 완료 |
| CharacterSpriteManifest | ✅ Round 234 완료 |
| CharacterSpriteAssetPolicy | ✅ Round 234 완료 |
| validate_sprites.sh | ✅ Round 234 완료 (NFD 대응) |
| 세나/카이/유나 스프라이트 | ⏳ DLC 대기 (releaseVisible = false) |
| 치코 v2 optional 스프라이트 | ⏳ 디자인팀 대기 |
| CharacterReactionEngine 구현 | ✅ Round 231A 완료 |
| AnimationState → Reaction 매핑 | ✅ 6개 이벤트 완료 |
| workflowCompleted → joy 연결 | ✅ Round 232 NotificationCenter 브리지 |
| multiRoomSwitched 연결 | ✅ Round 232 TeamStatusView 탭 훅 |
| SpriteKit 로더 | ✅ 기존 코드 유지 (변경 없음) |
| agentEmotions 연결 | ✅ CharacterReactionEventSink 완료 |
| delegate direct path | ⏳ deferred — agentEmotions 경로 먼저 검증 |
