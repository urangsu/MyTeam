# MyTeam — 개발자 온보딩 가이드

> **대상**: 새로 합류하는 개발자  
> **목적**: 제품이 무엇인지, 왜 이렇게 만들었는지, 어디서부터 시작하는지를 빠르게 파악한다.

---

## 1. 제품이 무엇인가

**MyTeam은 Mac 앱이다.**

사용자가 자연어로 말하면, AI 팀원들이 업무 문서/파일/표/정리 작업을 대신 처리한다.  
채팅처럼 생겼지만 "채팅 앱"이 아니다. **업무 자동화 도구**다.

### 한 줄 설명

> Mac 안에서 사용자의 자연어 요청을 받아, 문서·파일·표·정리 작업을 팀원처럼 처리하는 AI 업무 워크룸

### 핵심 루프

```
사용자가 자연어로 요청
  → 워크룸에서 AI 팀원이 처리
  → 문서/파일(Artifact) 생성
  → 사용자가 결과물 확인 및 후속 작업
  → (반복)
```

---

## 2. 왜 만들었나 (기획 배경)

### 타깃 사용자

| 유형 | 구체적인 니즈 |
|------|--------------|
| 사무직 | 반복 문서(회의록, 보고서, 체크리스트) 자동 생성 |
| 1인 창업자 | 혼자 처리해야 하는 기획/정리 업무 위임 |
| 콘텐츠 제작자 | 원고 초안, 아이디어 정리, 요약 |
| 기획자 | 보고서 초안, 액션아이템 추출 |
| 세무/회계/관리 | 표 정리, 체크리스트 관리 |

### 사용자 핵심 Pain Point

1. "AI는 쓰고 싶은데 프롬프트를 어떻게 써야 할지 모르겠다"
2. "결과가 텍스트로만 나와서 파일로 저장이 안 된다"
3. "대화창에 업무 기록이 섞여 나중에 찾기 힘들다"
4. "API 키 설정이 복잡해서 처음부터 포기했다"

### 우리의 답

- **API 키 없이도 작동**: 로컬 템플릿 fallback → 첫날부터 결과물 경험
- **결과물은 파일로**: Artifact(.md/.txt) → Finder에서 바로 열기 가능
- **업무 공간(워크룸) 단위로 관리**: 프로젝트별 대화 + 결과물 분리
- **버튼 한 번으로 시작**: 자연어 몰라도 카드 탭으로 업무 시작

---

## 3. 제품 구조 (화면 단위)

```
┌─────────────────────────────────────────────────┐
│  TeamStatusView (좌측 패널)                       │
│  ├─ 워크룸 목록 (사이드바)                          │
│  ├─ 현재 워크룸 채팅 로그                           │
│  └─ 하단 에이전트 nameplate (개별 대화 전환)         │
├─────────────────────────────────────────────────┤
│  AgentChatView (우측 메인 패널)                    │
│  ├─ WorkroomHomeView (빈 워크룸 진입점)            │
│  │   ├─ 문서 만들기 / 파일 맡기기 / 오늘 정리하기     │
│  │   ├─ 최근 결과물 (room-scoped, max 3)           │
│  │   └─ 다음 추천 액션 (결과물 있을 때만)            │
│  ├─ 채팅 로그 (메시지 + WorkResultCardView)        │
│  ├─ ArtifactCardView (결과물 카드)                 │
│  └─ 입력창                                        │
└─────────────────────────────────────────────────┘
```

### 워크룸 vs 개인 대화

| 워크룸 (teamWorkroom) | 개인 대화 (personalChat) |
|---|---|
| `agentIDs`에 `"team_all"` 포함 또는 2명 이상 | `agentIDs` 1명 |
| 문서 만들기 등 업무 CTA 표시 | 에이전트 1:1 대화 |
| 아이콘: `person.3` | 아이콘: `person` |

---

## 4. 핵심 개념 용어

| 용어 | 설명 | 코드 위치 |
|------|------|----------|
| **워크룸** | 업무 공간 단위. "채팅방"이 아님 | `ChatRoom`, `AgentWindowManager` |
| **Artifact** | 생성된 결과 파일 (.md 등) | `IndexedArtifact`, `ArtifactCardView` |
| **Skill** | 특정 업무 처리 단위 (로컬 or LLM) | `LocalSkillService`, `SkillResultRendererView` |
| **WorkResultCardView** | 긴 응답/결과를 말풍선 대신 카드로 표시 | `WorkResultCardView.swift` |
| **Room-scoped** | 결과물은 해당 워크룸 안에서만 보임 | `AgentWindowManager.currentRoomID` |
| **치코 (Chiko)** | 앱의 메인 AI 캐릭터. 상태에 따라 애니메이션 | `CharacterSpriteScene`, `CharacterReactionEngine` |
| **간편 모드** | 프롬프트 없이 버튼으로만 시작하는 초보자 모드 | `BeginnerMode`, `isBeginnerMode` |

### 금지 용어 (코드/UI에 쓰면 안 됨)

| 금지 | 대신 사용 |
|------|----------|
| 채팅방 | 워크룸 |
| 프로젝트 | 대화 (사이드바), 워크룸 N (기본 이름) |
| 스케줄 근무 | 예약 작업 |
| hash mismatch | 파일 내용이 바뀐 것 같아요 |
| 경로 오류 | 파일을 열 수 없음 |
| IMAP 기반 read-only 검토 중 | (표시 금지) |

---

## 5. 기술 아키텍처 개요

### 플랫폼

- **macOS SwiftUI** (Swift 5.9+, Xcode 15+)
- 외부 서버 없음 — 로컬 우선 (Local-first)
- AI 연결: LLM API (Keychain에 키 저장, UI에 절대 노출 안 함)

### 핵심 파일 지도

```
MyTeam/MyTeam/
├── WorkflowOrchestrator.swift   ← 모든 요청의 dispatch 진입점 (핵심)
├── AgentWindowManager.swift     ← 워크룸 상태, currentRoomID, 에이전트 관리
├── TeamStatusView.swift         ← 좌측 패널 전체 (~1200줄)
├── AgentChatView.swift          ← 우측 메인 채팅 패널 (~1100줄)
├── WorkroomHomeView.swift       ← 워크룸 진입 홈 (문서 만들기 CTA)
├── ChatModels.swift             ← ChatRoom, ChatLog, RoomKind 데이터 모델
├── IntentRouter.swift           ← 자연어 → 실행 경로 결정
├── GoalInterpreter.swift        ← 메시지 의도 분류
├── CapabilityAwareRouter.swift  ← 기능 허용/차단 판단
├── ArtifactCardView.swift       ← 결과물 카드 UI + 친절한 복구
├── CharacterSpriteScene.swift   ← 치코 캐릭터 애니메이션 (SpriteKit)
├── CharacterReactionEngine.swift← 이벤트 → 치코 감정 반응 연결
├── BeginnerMode.swift           ← 간편 모드 카드/안내 정의
├── RuntimeDiagnosticsService.swift ← 런타임 상태 스냅샷 (QA용)
├── ToolContractValidator.swift  ← 정책 준수 검증
└── RouterBurnInSuite.swift      ← 라우팅 회귀 테스트
```

### 요청 처리 파이프라인

```
사용자 입력
  → WorkflowOrchestrator.dispatch()
    → GoalInterpreter (의도 분류)
    → CapabilityAwareRouter (허용/차단)
    → LocalSkill 먼저 시도
    → IntentRouter (chitchat vs task)
    → 실행 (DocumentCreation / UniversalDocument / AppLaunchPack / ...)
    → Artifact 생성 + 등록
    → NotificationCenter → 치코 반응
```

### 자율성 레벨 (보안 정책)

| 레벨 | 내용 | 자동 실행 |
|------|------|----------|
| L1 | 답변만 | ✅ 자유 |
| L2 | 로컬 스킬 | ✅ 자유 |
| L3 | LLM 스킬 | ✅ 자유 |
| L4 | Artifact/파일 생성 | ⚠️ scope/risk 검증 필요 |
| L5 | 외부 쓰기 (메일/캘린더/결제/삭제) | 🚫 기본 차단, 명시 승인 필요 |

---

## 6. 치코 캐릭터 시스템

치코는 단순한 마스코트가 아니라 **제품 UX의 핵심 피드백 레이어**다.

### 상태 → 애니메이션

| 앱 이벤트 | 치코 상태 |
|---|---|
| 대기 중 | `idle` |
| 사용자 타이핑 중 | `typing` |
| AI 생각 중 | `thinking` |
| 결과물 완성 | `joy` |
| 에러/실패 | `sad` |
| 로그인/인사 | `greeting` |
| 백그라운드 작업 | `backwork` |
| 오래 대기 | `sleeping` |

### 스프라이트 파일 규칙

```
MyTeam/Resources/Sprites/치코/
  치코_{state}_{NNN:03d}.png
  예: 치코_idle_001.png, 치코_joy_024.png
```

신규 스프라이트 추가 시 `scripts/validate_sprites.sh` 실행 필수.

---

## 7. 개발 원칙 (코드 작성 기준)

### 1. 작게 만들어서 증명한다

> 가장 작은 버전으로 제품 루프를 먼저 증명한다.  
> 이론적 설계보다 실제로 동작하는 코드가 우선이다.

### 2. 첫 사용자 경험을 보호한다

- 빈 상태(empty state)에 기술 용어 노출 금지
- API 키 없어도 즉시 결과물을 경험할 수 있어야 함
- 진단 정보는 Debug/개발자 모드에서만 노출

### 3. 워크룸 경계를 지킨다

- A 방의 결과물이 B 방에 보이면 안 됨
- `currentRoomID`를 기준으로 모든 artifact 조회

### 4. 외부 쓰기는 항상 차단한다

- 메일 발송, 캘린더 등록, 파일 삭제, 계정 생성 → UI에서 명시적 차단
- 복구 버튼도 외부 쓰기 금지 (NotificationCenter 알림만 발생)

### 5. 빌드가 깨지면 즉시 멈춘다

```bash
# 빌드 명령어
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release build
```

- 에러 0개, 새로운 Swift warning 0개 기준
- duplicate build file warning 0개

---

## 8. 하면 안 되는 것 (절대 금지)

| 금지 항목 | 이유 |
|---|---|
| UI에 API 키/토큰 표시 | 보안 |
| UserDefaults에 민감 정보 저장 | Keychain만 허용 |
| 외부 메일/캘린더 자동 쓰기 | 사용자 승인 없는 외부 쓰기 금지 |
| Apple TTS 사용 | 사용자 거부 (Qwen3TTS or 침묵) |
| 진단 용어 UI 노출 ("해시 불일치", "경로 오류") | 사용자 친화 언어 사용 |
| 크로스-룸 artifact 링크 | 워크룸 경계 위반 |
| StoreKit 임의 수정 | App Store 정책 |
| Xcode GUI 자동화 | pbxproj 직접 수정만 허용 |
| "runtime verified" 표현 | 수동 QA 미완료 상태에서 금지 |

---

## 9. 주요 문서 위치

| 문서 | 경로 | 내용 |
|------|------|------|
| 제품 루프 정의 | `docs/WorkroomCoreLoop.md` | 6단계 워크룸 루프 |
| 워크룸 UI 정책 | `docs/WorkroomProductizationPolicy.md` | 화면 요소 요구사항 |
| 결과물 표시 정책 | `docs/ResultPresentationPolicy.md` | 카드 vs 말풍선 기준 |
| 용어 정책 | `docs/TerminologyPolicy.md` | 금지/공식 용어 대조표 |
| 방 종류 정책 | `docs/RoomKindPolicy.md` | teamWorkroom vs personalChat |
| 킬러 워크플로우 | `docs/KillerWorkflowPolicy.md` | 문서 만들기 설계 원칙 |
| 초보자 모드 스펙 | `docs/beginner/BeginnerModeProductSpec.md` | 간편 모드 전체 스펙 |
| 스프라이트 스펙 | `docs/character/SpriteSheetProductionSpec.md` | 치코 애니메이션 규격 |
| 수동 QA 체크리스트 | `docs/qa/ManualRuntimeQA_Round234.md` | 4개 시나리오 |
| 개발 로그 | `DEVLOG.md` | 라운드별 완료 이력 |
| 현재 작업 | `TASK.md` | Now / Next / Backlog |

---

## 10. 첫 날 할 일

```bash
# 1. 저장소 클론
git clone https://github.com/urangsu/MyTeam.git
cd MyTeam

# 2. 빌드 확인
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. 스프라이트 검증
bash scripts/validate_sprites.sh

# 4. 현재 작업 확인
cat TASK.md | head -80

# 5. 최근 변경 이력
git log --oneline -10
```

---

## 11. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|-----------|
| Swift 파일을 루트 `MyTeam/`에 추가 | `MyTeam/MyTeam/` (flat) + pbxproj 수동 등록 |
| 새 파일 추가 후 빌드 에러 | pbxproj에 PBXFileReference + PBXBuildFile + Group child + SourcesBuildPhase child 4개 등록 |
| 한국어 파일명을 bash grep으로 검색 | macOS NFD 이슈 → Python `os.listdir()+re` 사용 |
| "채팅방"이라고 코드에 씀 | → "워크룸" (용어 정책 참고) |
| artifact를 말풍선에 텍스트로 표시 | → WorkResultCardView 또는 ArtifactCardView 사용 |
| 외부 쓰기 버튼을 복구 UI에 넣음 | → NotificationCenter 알림만 허용 |

---

*마지막 업데이트: 2026-05-17 (Round 235 기준)*  
*관리자: 수석님 | 저장소: github.com/urangsu/MyTeam*
