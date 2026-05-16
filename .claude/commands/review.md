# Code Review Checklist (MyTeam)

## Before Committing

- [ ] Build: `xcodebuild ... Debug build` → **BUILD SUCCEEDED**
- [ ] Build: `xcodebuild ... Release build` → **BUILD SUCCEEDED**
- [ ] Git: `git status` → nothing to commit OR staged files clear
- [ ] Warnings: `grep "warning:" build.log` → 0 new Swift warnings
- [ ] Changes: `git diff --cached` → only intended files modified

## Product Mindset

- [ ] UX: Does this make first-time user flow faster or clearer?
- [ ] Risk: Reduces product/architecture bottleneck?
- [ ] Scope: Smaller, cleaner than alternative?
- [ ] Demo: Would this pass product review?

## Workroom Specific

- [ ] Room scope: No global `recentArtifacts()`, always `for: roomID`
- [ ] Artifacts: Cross-room linking impossible
- [ ] Character: No AnimationState/CharacterDialogues/SpriteAgentView changes
- [ ] Routing: All dispatch() calls include roomID

## Safety

- [ ] No password/token entry on UI
- [ ] No API key in chat/forms  
- [ ] File paths sanitized (no full paths exposed)
- [ ] Local fallback works (no API-key lockout)
- [ ] External writes (mail/calendar/delete) gated/blocked

## Commit Message

```
<type>: <short description>

- Bullet point 1
- Bullet point 2
- Build: Debug + Release succeeded

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
```

## Never

- ❌ Commit broken build
- ❌ Comment-only changes without fixing root cause  
- ❌ Modify pbxproj directly without validation
- ❌ Force-push main
- ❌ Remove character system files
