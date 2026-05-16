# Workroom Productization Policy

## Principle

**A workroom is a unit of work, not just a chat room.**

A workroom is a focused space where a team or individual completes specific business tasks. It has a goal, recent artifacts, and recommended next actions.

## Workroom Surface Requirements

### 1. Current Goal Display
- Show room-specific goal (if exists)
- Fallback: "무엇을 정리할까요?" (What shall we organize?)
- No API key prompts
- No technical diagnostics

### 2. Primary Actions (3 CTA)
Exact order:
- 문서 만들기 (Create document)
  - Default: 회의록 (meeting minutes)
  - Options: 회의록 / 체크리스트 / 보고서 초안
- 파일 맡기기 (Hand off file)
  - Trigger file intake workflow
- 오늘 정리하기 (Organize today)
  - Create daily summary/checklist

### 3. Recent Artifacts (max 3)
- Room-scoped ONLY
- From RecentArtifactIndexEntry(for: roomID)
- Never show another room's artifacts
- Metadata: filename, creation date
- UI: file icon, clickable row

### 4. Next Actions (max 4)
Enabled only if recent artifact exists:
- 요약하기 (Summarize)
  - korean.document-summary
- 표로 바꾸기 (Convert to table)
  - korean.table-summary
- 체크리스트로 바꾸기 (Convert to checklist)
  - korean.checklist
- 액션아이템 (Action items)
  - korean.action-items

All next actions require:
- Same room artifact only
- Missing/hashMismatch → hide action
- Room boundary enforced

## Forbidden

- ❌ Global recent artifacts list
- ❌ API key nag / Setup wizard
- ❌ Connector development status ("IMAP 기반 read-only 검토 중")
- ❌ Diagnostic leakage (build config, hash mismatches, etc.)
- ❌ Duplicate artifact surfaces (inline + rail + action surface)
- ❌ Full file path exposure
- ❌ Cross-room artifact linking

## Surface Layout

```
┌──────────────────────────────────┐
│ Workroom Title / Subtitle        │
├──────────────────────────────────┤
│ [Goal or "무엇을 정리할까요?"]     │
├──────────────────────────────────┤
│ 이번엔                           │
│ [문서] [파일] [정리]              │
├──────────────────────────────────┤
│ 최근 결과물                       │
│ - document1.md                   │
│ - document2.md                   │
│ - document3.md                   │
├──────────────────────────────────┤
│ 다음 작업                         │
│ - 요약하기                        │
│ - 표로 바꾸기                     │
│ - 체크리스트로 바꾸기             │
│ - 액션아이템                      │
└──────────────────────────────────┘
```

## Implementation Files

- `WorkroomHomeModel.swift` — UI projection (room-scoped data)
- `WorkroomHomeView.swift` — Workroom dashboard
- `WorkroomPrimaryAction` enum — 3 main CTAs
- `WorkroomNextAction` enum — follow-up actions
- `AgentChatView.swift` — Integration point

## Integration Points

### TeamStatusView
- Mini widget mode (no full workroom details)
- Links to AgentChatView
- Preserves team status at-a-glance view

### AgentChatView
- Shows WorkroomHomeView when room is teamWorkroom
- Personal chat shows agent-centric interface instead
- Clear separation: team vs. personal surface

## Testing

All cases in RouterBurnInSuite:
- workroom-open
- workroom-new
- workroom-create-document
- workroom-today-organize
- workroom-file-handoff

No new route enums. Reuse existing:
- `.universalDocument` for document creation
- `.fileIntake` for file handoff
- `.chatBasic` for navigation

## Next Phases

### Round 182A+: Workroom Analytics
- How many documents created per workroom
- Time spent in workroom
- Most-used next actions

### Round 183A+: Shared Workrooms
- Multiple team members in same workroom
- Real-time artifact sync
- Comment threads on artifacts

### Round 184A+: Workroom Templates
- Pre-configured goal templates
- Suggested next actions based on goal
- Custom primary actions per workroom type
