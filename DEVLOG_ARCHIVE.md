# MyTeam 개발 로그 아카이브 (2026-03-25 ~ 2026-04-17)

이 파일은 `DEVLOG.md`에서 분리된 과거 작업 이력입니다.

---

## [2026-04-17] [Antigravity] Swift 네이티브 TTS 파이프라인 완성 및 빌드 에러 전면 해결

### 작업 내용 요약
1.  **Chatterbox Multilingual Swift 네이티브 포팅 완료**
    - `apple/mlx-swift`를 기반으로 한 9개의 핵심 추론 파이프라인 파일 구현
    - `VoiceEncoder`, `LlamaModel`, `HiFTGenerator`, `T3Model`, `T3CondEnc`, `ChatterboxPipeline` 등
2.  **Xcode 빌드 에러 연쇄 해결**
    - **의존성**: pbxproj에 누락된 `MLXNN`, `MLXFFT`를 자동 등록하는 `add_mlx_products.rb` 스크립트 작성 및 실행
    - **Concurrency**: Swift 6 `@MainActor` 격리 충돌 에러를 `@preconcurrency import` 및 `nonisolated override init()` 패턴으로 전면 해결
    - **API 마이그레이션**: `SettingsView`의 `CLGeocoder`(macOS 26 deprecated)를 `MKReverseGeocodingRequest`로 교체
3.  **Graphify 지식 그래프 스킬 도입**
    - `graphifyy` 라이브러리 설치 및 전용 스킬(`.agents/skills/graphifyy`) 구축
    - 에이전트가 코드를 분석할 때 지식 그래프를 먼저 참고하도록 하는 `.agent/rules/graphify.md` 룰 추가
4.  **Git 형상 관리**
    - 주요 변경 사항을 Git에 커밋 및 푸시 완료 (`main` 브랜치)
    - `graphify-out/` 등 분석 아티팩트를 `.gitignore`에 등록하여 저장소 관리 최적화

---

## 2026-04-17 — TASK-0.1/0.3 완료: Chatterbox Multilingual MLX 한국어 PoC (@Claude Code)

### 결과
- **G0 통과**: Q4 모델 기준 25~30자 한국어 생성 1~1.8초 (기준 < 3초)
- **목소리 클로닝**: fp16/Q4 모두 기본값(파라미터 무설정)으로 레퍼런스 여성 목소리 재현 확인
- **채택 모델**: `theoracleguy/Chatterbox-Multilingual-MLX-v2-Q4` (속도 우선)

---

## 2026-04-08 ~ 2026-04-17: SettingsView UI 개편 및 보안 강화
- **KeychainManager**: API 키 보안 저장소 도입.
- **SettingsView**: 380x420 사이즈로 압축 및 탭 기반 UI 개편.
- **BPE Tokenizer**: Swift 네이티브 구현 완료.

---

## 2026-04-05 ~ 2026-04-07: ONNX -> MLX 전환 및 아키텍처 리팩토링
- **SpeechManager**: Massive Class 해체 (AudioPlaybackService, AudioCaptureService 등으로 분리).
- **MLX 전환**: ONNX T3 모델의 속도 한계로 인해 Apple Silicon GPU 가속을 위한 MLX 전환 성공.
- **Thinking Character UX**: 음성 합성 시간 동안 "생각 중" 인디케이터 표시 로직 도입.

---

## 2026-03-25 ~ 2026-04-05: 초기 아키텍처 및 UI 구현
- AgentWindowManager 단일 진실 공급원 아키텍처 확립.
- iMessage 스타일 채팅 UI 및 SpriteKit 기반 캐릭터 애니메이션 시스템 구축.
- 초기 ONNX 기반 TTS 실험 및 실패 기록.

---

> [!NOTE]
> 상세 로그가 필요하면 Git history 또는 이 아카이브 파일을 참조하세요.
