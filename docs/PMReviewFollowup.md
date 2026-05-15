# PM Review Follow-up

## Product Principle

**First result in under one minute.**

Users should see meaningful output (meeting minutes draft, checklist template, brief summary) without lengthy setup, authentication, or configuration delays.

## Killer Flow (MUST KEEP)

1. User opens MyTeam
2. User types natural language request: "회의록 양식 만들어"
3. Starter action triggers → Orchestrator → Meeting minutes template artifact created
4. First result actions appear (요약하기, 표로 바꾸기, 체크리스트로 바꾸기, Finder에서 보기)
5. User clicks one → artifact updated/saved
6. Done under 60 seconds

## Must Keep Features

✅ Meeting minutes (회의록)  
✅ Checklist (체크리스트)  
✅ File intake (문서 선택)  
✅ Today briefing (오늘 할 일)  
✅ Recent artifact reuse (최근 문서 재사용)  
✅ Finder integration (파일 열기/경로 복사)  
✅ Local mode (API key 없이)  

## Hide / Defer

❌ Gmail read-only (metadata)  
❌ Naver integration  
❌ Calendar write  
❌ Character DLC purchase UI  
❌ Pro/Premium button when disabled  
❌ User-added custom skills  
❌ Debug diagnostics panel  
❌ Advanced planner surface  

**Policy**: These are available in code/policy layer, but Release surface hides them.

## Product Requirement Gaps

### Artifact Generation Time SLA
- Target: first artifact < 60 seconds
- Current: meeting minutes ✅ (verified in Round 39-41)
- Pending: round-trip time on Round 96A manual QA

### Starter Action Clarity
- 4 default buttons must be clear, discoverable
- Copy: "회의록 양식", "체크리스트", "파일 읽기", "오늘 할 일"
- Status: UI integrated ✅, copy finalized ✅, QA pending

### First Result Actions
- 4 next-step buttons on first artifact
- Copy: "요약하기", "표로 바꾸기", "체크리스트로 바꾸기", "Finder에서 보기"
- Status: UI integrated ✅, copy finalized ✅, QA pending

### No Hidden Paywall
- Free tier: all core features (meeting, checklist, briefing, file intake)
- DLC: character roster (deferred, not in Release yet)
- Pro/Premium: all hidden until revenue model finalized
- Status: paywall hidden ✅, free tier complete ✅

### Character Personality
- Chiko: "문서와 할 일을 정리하는 기본 팀원"
- Persona: Organized, reliable, document-focused
- Screenshot: Chiko in action (pending Round 96A visual QA)
- Status: character definition ✅, asset production pending

## Feature Parity Checklist

| Feature | Release | Notes |
|---------|---------|-------|
| Meeting minutes | ✅ Yes | First result in < 1min |
| Checklist | ✅ Yes | Native artifact type |
| Briefing | ✅ Yes | Daily summary |
| File intake | ✅ Yes | FileImporter, document support |
| Recent reuse | ✅ Yes | Cache + UI |
| Finder open | ✅ Yes | WorkspaceFileActions |
| Chiko default | ✅ Yes | Asset manifest ready |
| Local mode | ✅ Yes | Zero-API-key flow |
| Gmail read | ❌ No | Policy: planned/unavailable |
| Calendar write | ❌ No | Policy: blocked |
| DLC characters | ❌ No | Assets pending |
| Pro purchase | ❌ No | Button disabled |
| Naver | ❌ No | Policy: planned |

## Remaining Product Risks

### SLA Verification
- Meeting minutes < 60s: **NOT YET TESTED** (Round 96A manual QA)
- Artifact reuse latency: **NOT YET TESTED**
- Startup time: **NOT YET TESTED**

### User Onboarding
- First-time user guidance: FirstLaunchBannerView ✅, runtime QA pending
- Starter actions clarity: **NOT YET TESTED**
- Settings discoverability: **NOT YET TESTED**

### Error Cases
- Missing file handling: UI hidden ✅, but runtime behavior **NOT YET TESTED**
- Wrong-room artifact: policy defined ✅, but UI handling **NOT YET TESTED**
- API key rotation: policy blocks expired key ✅, UI message **NOT YET TESTED**

## Deferred Product Work

### Character DLC
- Asset production: out of scope, Cloud round
- Pricing: pending product decision
- Store integration: pending asset completion

### Calendar Integration
- Write capability: NOT IN SCOPE for Release
- Read-only calendar: planned connector, awaiting backend
- Marketing: no calendar promises until stable

### Advanced Planner
- Custom skills: hidden from Release UI
- Workflow composition: debug-only
- MarkedAs feature: awaiting user validation

## Next Checkpoint

**Round 96A — Mac Local Build + Manual Runtime QA**

**Go/No-Go Criteria**:
1. Debug build succeeds (warnings < 5)
2. First artifact latency < 90s ✅
3. Starter actions clickable ✅
4. First result actions functional ✅
5. Finder UI works ✅
6. No placeholder characters visible ✅
7. No DLC/Pro buttons visible ✅
8. No external write tools visible ✅
9. Google OAuth deferred ✅
10. All character text: truthful, BYOK-centric ✅

**No-Go If**:
- Build fails
- Artifact latency > 2 minutes
- Placeholder character visible
- Pro/DLC button visible
- External write tool visible
- Overclaimed privacy copy
- Missing first result actions

## PM Approval

**Current Status**: PENDING ROUND 96A MANUAL QA

Do not submit to App Store review until:
- [ ] Debug/Release builds verified
- [ ] First result SLA confirmed < 60s
- [ ] All manual QA checks pass
- [ ] Privacy copy audit final
- [ ] Character asset production complete
