# Workroom Core Loop

## Definition

The **Workroom Core Loop** is the primary usage pattern for MyTeam. It describes a complete business task cycle within a single workroom.

## The 6-Step Loop

```
1. Open Workroom
   ↓
2. Create Document
   ↓
3. Review Result Card
   ↓
4. Use Inline Artifact
   ↓
5. Reuse Recent Document
   ↓
6. Continue Next Action
   ↓
(repeat or exit)
```

## Step Details

### 1. Open Workroom

**Entry Point**
- TeamStatusView: click on workroom
- AgentChatView: workroom already open
- Sidebar: workroom list

**What Happens**
- AgentChatView loads current room
- If teamWorkroom: show WorkroomHomeView
- If personalChat: show agent conversation
- roomID is set for all subsequent operations

**Data Loaded**
```
currentRoomID: UUID
isTeamWorkroom: Bool = agentIDs.contains("team_all")
recentArtifacts: [IndexedArtifact] = manager.recentArtifactIndexEntries(for: roomID)
```

### 2. Create Document

**User Action**
Click one of three primary actions in WorkroomHomeView:
- 문서 만들기 (Create document) — default action
- 파일 맡기기 (File handoff)
- 오늘 정리하기 (Organize today)

**Document Creation Flow** (most common)
```
Click "문서 만들기"
   ↓
Choose type:
  - 회의록 (Meeting minutes)
  - 체크리스트 (Checklist)
  - 보고서 초안 (Report draft)
   ↓
DocumentCreationService.createLocalDocument() OR
UniversalDocumentSkillService.runWithLLM()
   ↓
IndexedArtifact created + registered
RecentArtifactIndexEntry added
   ↓
WorkflowOrchestrator.removeProgressAndPost()
```

**Artifact Registration**
```swift
// IndexedArtifact properties
id: UUID().uuidString
workflowID: UUID().uuidString
title: "2026-05-16 회의록"
type: .text
filename: "2026-05-16_회의록.md"
roomID: roomID.uuidString

// RecentArtifactIndexEntry
artifactID: artifact.id
roomID: roomID  // ← room-scoped
createdAt: Date()
contentHash: SHA256(template)
fileSizeBytes: template.count
```

**Result**
- Message posted to chat: "# 회의록 초안을 만들었습니다..."
- Artifact stored in Workspace
- Recent artifact rail updated (max 3)

### 3. Review Result Card

**UI Display**
WorkResultCardView with document-specific styling:
```
┌─────────────────────────────────┐
│ 📋 회의록 초안 [time]             │
├─────────────────────────────────┤
│ ## 회의록                        │
│                                 │
│ ### 참석자                       │
│ - [name]                        │
│                                 │
│ [... 300-char preview]          │
│ [펼치기 button if > 500 chars]   │
├─────────────────────────────────┤
│ 관련 결과물                      │
│ [inline ArtifactCardView]        │
└─────────────────────────────────┘
```

**User Can**
- Read preview (300 chars)
- Expand full content with "펼치기"
- Click artifact to open in Finder
- See artifact metadata (filename, size, date)

### 4. Use Inline Artifact

**Within WorkResultCardView**
- Inline ArtifactCardView shows:
  - File icon
  - Filename
  - File size
  - Open button
  - Finder button
- No full path exposure
- No diagnostic jargon

**User Actions**
- Click "열기" → open artifact with default app
- Click "Finder" → reveal in Finder
- Click artifact name → open detail view

### 5. Reuse Recent Document

**Next Actions Become Available**
Only if recent artifact exists in same room:
```
최근 artifact found?
  Yes → Show next actions
  No → Hide "다음 작업"
```

**Available Actions** (max 4)
```
- 요약하기 (summarize artifact)
- 표로 바꾸기 (convert to table)
- 체크리스트로 바꾸기 (convert to checklist)
- 액션아이템 (extract action items)
```

**Implementation**
```swift
// Get recent artifact from same room
let entries = manager.recentArtifactIndexEntries(for: roomID)
if let recent = entries.first {
    // Reuse in skill: document-summary, table-summary, etc.
    // Pass artifact content as input
}
```

**User Experience**
```
User sees 4 buttons: "요약해줘", "표로...", etc.
Click → Skill runs with recent artifact as context
Result → New message + new artifact (or inline)
Next artifact added to rail (still max 3)
```

### 6. Continue Next Action

**After Next Action Completes**
- New result card appears
- Old artifact remains in recent rail
- Both artifacts available for further reuse
- Loop continues or exits based on user input

**Example Flow**
```
1. Create meeting minutes
2. Review result card
3. Use inline artifact
4. Click "표로 바꿔줘" → get table version
5. Click "액션아이템 뽑아줘" → get action list
6. Review all 3 artifacts in rail
7. Close or start new task
```

## Room-Scoped Boundaries

**Critical Invariant**
All steps 2-6 operate within the same `roomID`:
- recentArtifacts lookup: `for: roomID` only
- Next actions: same room only
- Cross-room artifact reference: **blocked**

**Example Violation**
```swift
// ❌ WRONG: Global recent artifacts
let recentArtifacts = manager.recentArtifacts

// ✅ CORRECT: Room-scoped
let recentArtifacts = manager.recentArtifactIndexEntries(for: roomID)
```

## Local Fallback Guarantee

Even without API key:
- Document creation still works (local template)
- Artifact still registers
- Recent rail still populates
- Next actions still appear (same room)

```swift
// API key absent → use LocalDocumentTemplate
if !apiKeyAvailable {
    let template = LocalDocumentTemplate.generate(for: .meetingMinutes)
    // Rest of loop proceeds identically
}
```

## Metrics for Success

### Workroom Core Loop Completion
- User creates document → 🎯 Step 2
- Result card appears → 🎯 Step 3
- User clicks artifact → 🎯 Step 4
- User clicks next action → 🎯 Steps 5-6
- Loop repeats → 🎯 Full cycle

### Room-Scoped Safety
- All recent artifacts from correct room ✓
- Cross-room lookup blocked ✓
- Missing artifact → next action hidden ✓
- hashMismatch → artifact still shows ✓

### No API Lockout
- Fallback template generated ✓
- Artifact stored even if no LLM ✓
- User sees immediate value ✓

## Iteration

### Round 181A-195Z: Core Loop Foundation
- ✓ WorkroomHomeView with primary actions
- ✓ Room-scoped recent artifacts
- ✓ Next actions (4 max, same-room only)
- ✓ AgentChatView integration
- ✓ Local fallback preserved

### Round 182A+: Loop Optimization
- Faster artifact loading
- Smoother next-action transitions
- Reuse history (did user take this action before?)

### Round 183A+: Loop Collaboration
- Multiple users in workroom
- Real-time artifact updates
- Threaded comments on artifacts

### Round 184A+: Loop Analytics
- Most-used next actions per room type
- Time to document-create
- Average artifacts per workroom
- Fallback usage rate
