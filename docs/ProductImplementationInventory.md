# Product Implementation Inventory
**기준**: Round 236 | 2026-05-17  
**목적**: 미구현/미완성 기능 현황을 팀이 공유하고, 우선순위를 판단한다.

---

## P0 — 현재 UX 결함 (수동 QA 필요)

| 항목 | 현재 상태 | 사용자 노출 | 테스트 가능 | 블로커 | 권장 다음 액션 |
|------|----------|------------|------------|--------|--------------|
| Light mode 텍스트 가독성 | Round 235에서 MT Readability Token 적용 완료. 수동 확인 필요 | 예 | 빌드 후 시각 확인 | — | ManualRuntimeQA_Round234.md 시나리오 실행 |
| Room switching (개인방 ↔ 팀방) | Round 235에서 openPersonalChat(for:) 구현 완료 | 예 | 빌드 후 탭 테스트 | — | 하단 nameplate 클릭 동작 수동 확인 |
| Room rename | Round 236에서 renameRoom(id:newName:) 구현 완료 | 예 | 빌드 후 수동 확인 | — | 이름 변경 후 sidebar 반영 확인 |
| Room-scoped messages | AgentWindowManager roomID 기준 구현 완료 | 예 | 빌드 후 방 전환 테스트 | — | 방 전환 시 메시지 로그 분리 확인 |
| FloatingPanel constraints loop | 미재현. 발생 시 repro 필요 | 아니오 (개발자만) | — | repro 없음 | 재발 시 AutoLayout 로그 확인 |

---

## P1 — 사용자 테스트 전에 skeleton 필요

| 항목 | 현재 상태 | 사용자 노출 | 테스트 가능 | 블로커 | 권장 다음 액션 |
|------|----------|------------|------------|--------|--------------|
| Google Calendar read-only OAuth | skeleton 없음 | 아니오 | 아니오 | OAuth client ID 필요 | client ID 설정 → read-only scope 요청 → 일정 목록 표시 |
| Gmail metadata/read-only skeleton | skeleton 없음 | 아니오 | 아니오 | OAuth client ID 필요 | 메타데이터만 read → 본문 read는 별도 승인 |
| OAuth client ID Settings UI | 없음 | 아니오 | 아니오 | — | SettingsView에 "Google 연결" 섹션 추가 |
| Connector 연결 상태 표시 | 없음 (미연결 시 숨김) | 아니오 | 아니오 | — | 설정 화면에 연결됨/미연결 상태 표시 |
| File intake 지원 포맷 UI | 미정 | 아니오 | 아니오 | — | 드래그 앤 드롭 지원 포맷 레이블 추가 |
| StoreKit sandbox 구매 상태 표시 | 없음 | 아니오 | 아니오 | — | sandbox purchase QA |

---

## P2 — 나중에 (Backlog)

| 항목 | 예상 시점 | 비고 |
|------|----------|------|
| Gmail send | 미구현 (영구 차단 정책 아님, 향후 검토) | L5 외부 쓰기 — 명시 승인 플로우 필요 |
| Calendar write (일정 생성/수정) | 미구현 | L5 외부 쓰기 |
| Naver 메일/캘린더 | 계획 없음 | primary UI 숨김 |
| PDF/DOCX/XLSX/PPTX 파서 | 미구현 | 파일 맡기기 이후 |
| DART / 법제처 live skill | 미구현 | 전문 데이터 연동 |
| 사용자 추가 스킬 | 미구현 | 플러그인 아키텍처 필요 |
| 캐릭터 DLC 구매 화면 | 미구현 | StoreKit + 캐릭터 sprite 완성 후 |
| 세나/카이/유나 스프라이트 제작 | 디자인팀 대기 | releaseVisible = false |
| 치코 v2 optional 상태 | 디자인팀 대기 | sleeping/drop/clockout 등 |
| 수동 QA 전체 | ManualRuntimeQA_Round234.md | 4개 시나리오 미완 |

---

## 기능 상태 범례

- ✅ 완료: 코드 구현 + 빌드 확인
- 🔧 부분: skeleton 또는 UI stub 존재
- ⏳ 대기: 디자인/외부 의존성 대기
- ❌ 미구현: 코드 없음
- 🚫 차단: 정책상 구현 금지 (L5 외부 쓰기 등)

---

*수동 QA 결과는 docs/qa/ManualRuntimeQA_Round234.md에 기록*
