# Sprite Asset Intake

이 폴더는 디자이너/AI 이미지 생성 결과물을 받아 검수하는 intake 폴더입니다.

## 구조

```
Sprites/
  치코/     ← 치코 v1 스프라이트 intake (primary character)
  세나/     ← 세나 intake (DLC — 미출시)
  카이/     ← 카이 intake (DLC — 미출시)
  유나/     ← 유나 intake (DLC — 미출시)
```

## 실제 런타임 경로

Xcode에 등록된 스프라이트는 `MyTeam/Resources/Sprites/{캐릭터ID}/` 에 있습니다.
이 intake 폴더는 **검수 전 단계**입니다.

intake → 검수 통과 → `MyTeam/Resources/Sprites/` 에 복사 → pbxproj 등록 → 빌드 확인

## Validator

```bash
./scripts/validate_sprites.sh
```

## 관련 문서

- `docs/character/ChikoSpriteSheetHandoff.md`
- `docs/character/CharacterSpriteRosterRoadmap.md`
- `docs/beginner/BeginnerModeProductSpec.md`
