# Chiko Sprite Intake

## 현재 상태

치코 v1 스프라이트 674개 (`MyTeam/Resources/Sprites/치코/`)에 이미 포함됨.
22개 상태 완비: agree, angry, backwork, clockin, clockout, confused, disagree,
drag, drop, greeting, idle, idle_loop, joy, landing, praise, resting, sad,
sleeping, speaking, thinking, typing, typing_return

## File convention

```
{characterID}_{state}_{index:03d}.png
```

Example:
- 치코_idle_001.png
- 치코_idle_002.png
- 치코_typing_001.png
- 치코_greeting_001.png
- 치코_joy_001.png

characterID = `치코` (한글, 런타임에서 그대로 사용)

## Required v1 states

| state | rawValue | frames | 비고 |
|-------|----------|--------|------|
| idle | idle | 11 | ✅ 있음 |
| typing | typing | 38 | ✅ 있음 |
| thinking | thinking | 24 | ✅ 있음 (idle 폴백) |
| speaking | speaking | 13 | ✅ 있음 |
| greeting | greeting | 36 | ✅ 있음 |
| joy | joy | 24 | ✅ 있음 |
| sad | sad | 24 | ✅ 있음 |
| confused | confused | 36 | ✅ 있음 |
| drag | drag | 24 | ✅ 있음 |
| landing | landing | 48 | ✅ 있음 |
| clockIn | clockin | 48 | ✅ 있음 |
| backToWork | backwork | 24 | ✅ 있음 |
| sleeping | sleeping | 48 | ✅ 있음 (resting 폴백) |

## Fallback chain (CharacterSpriteScene.swift)

```
thinking   → idle
sleeping   → resting
clockOut   → resting
disagree   → angry
praise     → agree
```

최종 폴백: idle (반드시 존재해야 함)

## Rules

- transparent PNG (alpha)
- same canvas size across all frames of same character
- same baseline (feet position)
- no text baked into image
- no UI background (no chat bubble, no panel)
- subtle motion — not cartoon exaggerated
- work-focused aesthetic — desk/laptop context
- fallback image `치코_profile` must remain in xcassets

## v2 신규 상태 후보 (미구현)

- resting (현재 sleeping 폴백 대상 — 별도 상태 추가 가능)
- agree (현재 praise 폴백 대상)
- typing_return (짧은 복귀 모션)
- idle_loop (긴 대기 루프)

## Intake 절차

1. 이 폴더에 PNG 파일 추가
2. `./scripts/validate_sprites.sh` 실행 → convention 검사
3. `MyTeam/Resources/Sprites/치코/`에 복사
4. Xcode target에 등록 (pbxproj)
5. Debug + Release BUILD SUCCEEDED 확인
