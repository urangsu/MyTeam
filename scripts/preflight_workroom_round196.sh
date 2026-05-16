#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Workroom Round 196A-230Z Preflight Check"
echo "=========================================="
echo ""

cd /Users/su/Desktop/MyTeam

# MARK: - Git Status
echo "== Git Status =="
git status --short
echo ""

# MARK: - Workroom Files
echo "== Workroom Files =="
ls -la MyTeam/WorkroomHomeModel.swift MyTeam/WorkroomHomeView.swift MyTeam/WorkroomActionTypes.swift 2>/dev/null || echo "Some files missing"
echo ""

# MARK: - Workroom Enum Definitions
echo "== Workroom Enum Consolidation =="
grep -R "enum WorkroomPrimaryAction\|enum WorkroomNextAction" -n MyTeam --include="*.swift" || echo "✓ No enum redeclarations"
echo ""

# MARK: - Character Runtime Files
echo "== Character System Files =="
ls -la MyTeam/CharacterDialogues.swift MyTeam/SpriteAgentView.swift MyTeam/CharacterSpriteScene.swift MyTeam/AgentSeatView.swift 2>/dev/null || echo "Some files missing"
echo ""

# MARK: - Character Planning Docs
echo "== Character Planning Documentation =="
ls -la docs/character/CharacterReactionBridgeBacklog.md docs/character/SpriteSheetProductionSpec.md docs/character/CharacterReactionEnginePlan.md 2>/dev/null || echo "Some docs missing"
echo ""

# MARK: - Project Configuration
echo "== CLAUDE.md Project Config =="
ls -la .claude/CLAUDE.md 2>/dev/null || echo "CLAUDE.md missing"
echo ""

echo "== Command Scripts =="
ls -la .claude/commands/*.md 2>/dev/null | wc -l && echo "scripts present" || echo "scripts missing"
echo ""

# MARK: - Forbidden Copy Check
echo "== Forbidden Privacy Copy =="
grep -R "외부 서버 없음\|완전 로컬\|내 기기 안에서만\|어떤 데이터도 외부로 나가지\|서버 없음" -n MyTeam docs 2>/dev/null || echo "✓ No misleading copy"
echo ""

# MARK: - Room Scope Validation
echo "== Room-Scoped Recent Artifacts =="
echo "Global recentArtifacts() calls:"
grep -R "recentArtifacts()" -n MyTeam --include="*.swift" 2>/dev/null | wc -l && echo "Count above (should be 0)"
echo "Scoped recentArtifacts(for:) calls:"
grep -R "recentArtifacts(for" -n MyTeam --include="*.swift" 2>/dev/null | wc -l && echo "Count above"
echo ""

# MARK: - Workroom Routing Terms
echo "== Workroom Action Dispatch Terms =="
grep -R "회의록 양식\|방금 만든 문서\|오늘 할 일" -n MyTeam --include="*.swift" 2>/dev/null | head -10
echo ""

# MARK: - Character Reaction References
echo "== Character System Preservation =="
grep -R "CharacterDialogues\|SpriteAgentView\|CharacterSpriteScene\|agentEmotions\|AnimationState" -l MyTeam --include="*.swift" 2>/dev/null | wc -l && echo "files referencing character system"
echo ""

# MARK: - Build Debug
echo "== Build Debug Configuration =="
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -3 || echo "Build check error"
echo ""

# MARK: - Build Release
echo "== Build Release Configuration =="
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -3 || echo "Build check error"
echo ""

# MARK: - Summary
echo "=========================================="
echo "Preflight Check Complete"
echo "=========================================="
