#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Workroom Round 196A-231A Preflight Check"
echo "=========================================="
echo ""

cd /Users/su/Desktop/MyTeam

# MARK: - Git Status
echo "== Git Status =="
git status --short
echo ""

# MARK: - Workroom Core Files
echo "== Workroom Core Files =="
ls -la MyTeam/WorkroomHomeModel.swift MyTeam/WorkroomHomeView.swift MyTeam/WorkroomActionTypes.swift 2>/dev/null || echo "⚠ Some Workroom core files missing"
echo ""

# MARK: - Character Reaction Engine Files (Round 231A)
echo "== Character Reaction Engine Files (Round 231A) =="
ls -la MyTeam/WorkroomCharacterEvent.swift MyTeam/CharacterReactionEngine.swift MyTeam/CharacterReactionEventSink.swift 2>/dev/null || echo "⚠ Some CharacterReaction files missing"
echo ""

# MARK: - pbxproj Registration (CharacterReaction)
echo "== pbxproj CharacterReaction Registration =="
echo -n "WorkroomCharacterEvent.swift: "
grep -c "WorkroomCharacterEvent.swift" MyTeam/MyTeam.xcodeproj/project.pbxproj && echo " (should be ≥1)" || echo "NOT REGISTERED"
echo -n "CharacterReactionEngine.swift: "
grep -c "CharacterReactionEngine.swift" MyTeam/MyTeam.xcodeproj/project.pbxproj && echo " (should be ≥1)" || echo "NOT REGISTERED"
echo -n "CharacterReactionEventSink.swift: "
grep -c "CharacterReactionEventSink.swift" MyTeam/MyTeam.xcodeproj/project.pbxproj && echo " (should be ≥1)" || echo "NOT REGISTERED"
echo ""

# MARK: - Workroom Enum Consolidation
echo "== Workroom Enum Consolidation =="
ENUM_COUNT=$(grep -R "enum WorkroomPrimaryAction\|enum WorkroomNextAction" -n MyTeam --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ENUM_COUNT" -le 2 ]; then
    echo "✓ enum definitions: $ENUM_COUNT (OK — WorkroomActionTypes.swift only)"
else
    echo "⚠ DUPLICATE enum definitions found: $ENUM_COUNT"
    grep -R "enum WorkroomPrimaryAction\|enum WorkroomNextAction" -n MyTeam --include="*.swift" 2>/dev/null
fi
echo ""

# MARK: - CharacterMood/CharacterActivity 미도입 확인
echo "== CharacterMood / CharacterActivity 미도입 확인 =="
if grep -R "CharacterMood\|CharacterActivity\|CharacterEmotionMode" -l MyTeam --include="*.swift" 2>/dev/null | grep -q .; then
    echo "⚠ CharacterMood / CharacterActivity references found:"
    grep -R "CharacterMood\|CharacterActivity\|CharacterEmotionMode" -n MyTeam --include="*.swift" 2>/dev/null
else
    echo "✓ CharacterMood / CharacterActivity 미사용"
fi
echo ""

# MARK: - AnimationState 사용 확인
echo "== AnimationState 사용 확인 =="
ANIM_COUNT=$(grep -R "AnimationState" -l MyTeam --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
echo "AnimationState를 참조하는 파일 수: $ANIM_COUNT"
grep -R "AnimationState" -l MyTeam --include="*.swift" 2>/dev/null | head -10
echo ""

# MARK: - Character System Core Files
echo "== Character System Core Files =="
ls -la MyTeam/CharacterDialogues.swift MyTeam/SpriteAgentView.swift MyTeam/CharacterSpriteScene.swift MyTeam/AgentSeatView.swift 2>/dev/null || echo "⚠ Some character system files missing"
echo ""

# MARK: - Character Planning Docs
echo "== Character Planning Documentation =="
ls -la docs/character/CharacterReactionBridgeBacklog.md docs/character/SpriteSheetProductionSpec.md docs/character/CharacterReactionEnginePlan.md 2>/dev/null || echo "⚠ Some docs missing"
echo ""

# MARK: - ToolContractValidator / RouterBurnInSuite 존재 확인
echo "== ToolContractValidator / RouterBurnInSuite =="
ls -lh MyTeam/ToolContractValidator.swift MyTeam/RouterBurnInSuite.swift 2>/dev/null || echo "⚠ Validator/BurnIn files missing"
echo ""

# MARK: - Project Configuration
echo "== CLAUDE.md Project Config =="
ls -la .claude/CLAUDE.md 2>/dev/null || echo "CLAUDE.md missing"
echo ""

echo "== Command Scripts =="
ls -la .claude/commands/*.md 2>/dev/null | wc -l && echo "scripts present" || echo "scripts missing"
echo ""

# MARK: - Forbidden Privacy Copy Check (Swift 소스만 검사)
echo "== Forbidden Privacy Copy (Swift sources only) =="
if grep -R "외부 서버 없음\|완전 로컬\|내 기기 안에서만\|어떤 데이터도 외부로 나가지\|서버 없음" -n MyTeam --include="*.swift" 2>/dev/null | grep -q .; then
    echo "⚠ Forbidden copy in Swift source:"
    grep -R "외부 서버 없음\|완전 로컬\|내 기기 안에서만\|어떤 데이터도 외부로 나가지\|서버 없음" -n MyTeam --include="*.swift" 2>/dev/null
else
    echo "✓ No misleading privacy copy in Swift sources"
fi
echo ""

# MARK: - Room Scope Validation
echo "== Room-Scoped Recent Artifacts =="
GLOBAL_COUNT=$(grep -R "recentArtifacts()" -n MyTeam --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
SCOPED_COUNT=$(grep -R "recentArtifacts(for" -n MyTeam --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
echo "Global recentArtifacts() calls: $GLOBAL_COUNT (should be 0)"
echo "Scoped recentArtifacts(for:) calls: $SCOPED_COUNT"
echo ""

# MARK: - Build Debug
echo "== Build Debug Configuration =="
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | grep -v "appintents\|skipping cache" | tail -3 || echo "Build check error"
echo ""

# MARK: - Build Release
echo "== Build Release Configuration =="
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | grep -v "appintents\|skipping cache" | tail -3 || echo "Build check error"
echo ""

# MARK: - Summary
echo "=========================================="
echo "Preflight Check Complete"
echo "=========================================="
