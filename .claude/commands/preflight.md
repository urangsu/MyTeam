# Preflight Validation (Pre-Release)

**Run before any tag or release commit.**

## Build Validation

```bash
# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData/MyTeam*
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug clean build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release clean build
```

Must both: `** BUILD SUCCEEDED **`, 0 errors, 0 new warnings.

## Static Checks

```bash
# Room scope
grep -r "recentArtifacts()" MyTeam | grep -v "for: " && echo "ERROR: global artifacts found" || echo "✓ Room scope OK"

# Character preservation
grep -r "CharacterDialogues\|SpriteAgentView\|CharacterSpriteScene" MyTeam | wc -l | xargs echo "Found N character refs"

# Forbidden terms
grep -ri "외부 서버 없음\|완전 로컬\|어떤 데이터도" MyTeam docs || echo "✓ No misleading copy"

# Workroom integrity
grep -r "WorkroomHomeView\|WorkroomHomeModel\|Workroom.*Action" MyTeam | head -20
```

## Git State

```bash
git status         # Clean working tree
git log -5 --oneline  # Recent commits clean
git diff HEAD~1    # Show last commit
```

## Commit Checklist

```bash
git add .
git status --short

# Review
git diff --cached | less

# Commit
git commit -m "feat/fix: clear message

- Changelog item 1
- Changelog item 2

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"

# Verify
git log --oneline -1
git push origin main
```

## Post-Commit

```bash
git log -5 --oneline --graph
git status
```

Must be: **nothing to commit, working tree clean**
