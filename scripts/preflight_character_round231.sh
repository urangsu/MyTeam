#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Character Reaction + Sprite Handoff"
echo "Preflight Check — Round 231/232"
echo "=========================================="
echo ""

cd /Users/su/Desktop/MyTeam

# MARK: - Git Status
echo "== Git Status =="
git status --short
echo ""

# MARK: - CharacterReaction Engine Files
echo "== CharacterReaction Engine Files =="
ls -la MyTeam/WorkroomCharacterEvent.swift MyTeam/CharacterReactionEngine.swift MyTeam/CharacterReactionEventSink.swift 2>/dev/null || echo "⚠ Some CharacterReaction files missing"
echo ""

# MARK: - CharacterMood / CharacterActivity 미사용 확인
echo "== CharacterMood / CharacterActivity 미사용 확인 =="
# ToolContractValidator 자체의 에러 메시지 문자열은 제외 (validator가 금지 표현을 언급하는 것은 정상)
CHAR_MOOD_HITS=$(grep -Rn "CharacterMood\|CharacterActivity\|CharacterEmotionMode" MyTeam --include="*.swift" 2>/dev/null \
    | grep -v "ToolContractValidator\|//.*CharacterMood\|//.*CharacterActivity" || true)
if [ -n "$CHAR_MOOD_HITS" ]; then
    echo "⚠ CharacterMood / CharacterActivity references found in Swift (actual code):"
    echo "$CHAR_MOOD_HITS"
else
    echo "✓ CharacterMood / CharacterActivity 미사용"
fi
echo ""

# MARK: - AnimationState 사용 확인
echo "== AnimationState 사용 확인 =="
ANIM_COUNT=$(grep -Rl "AnimationState" MyTeam --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
echo "AnimationState를 참조하는 파일 수: $ANIM_COUNT"
grep -Rl "AnimationState" MyTeam --include="*.swift" 2>/dev/null | head -10
echo ""

# MARK: - Character System Core Files
echo "== Character System Core Files =="
ls -la MyTeam/CharacterDialogues.swift MyTeam/SpriteAgentView.swift MyTeam/CharacterSpriteScene.swift MyTeam/AgentSeatView.swift 2>/dev/null || echo "⚠ Some character system files missing"
echo ""

# MARK: - agentEmotions 연결 확인
echo "== agentEmotions 연결 확인 =="
echo -n "AgentWindowManager.agentEmotions 정의: "
grep -c "agentEmotions:" MyTeam/AgentWindowManager.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo -n "CharacterReactionEventSink agentEmotions 업데이트: "
grep -c "agentEmotions\[agentID\]" MyTeam/CharacterReactionEventSink.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo -n "AgentSeatView agentEmotions 읽기: "
grep -c "agentEmotions" MyTeam/AgentSeatView.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo ""

# MARK: - Workroom Event Firing Points
echo "== Workroom Event Firing Points =="
echo -n "WorkroomHomeView.onAppear → notifyWorkroomOpened: "
grep -c "notifyWorkroomOpened" MyTeam/WorkroomHomeView.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo -n "TeamStatusView → notifyDocumentGenerationStarted: "
grep -c "notifyDocumentGenerationStarted" MyTeam/TeamStatusView.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo -n "TeamStatusView → notifyArtifactReuseRequested: "
grep -c "notifyArtifactReuseRequested" MyTeam/TeamStatusView.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo -n "TeamStatusView → notifyRoomSwitched: "
grep -c "notifyRoomSwitched" MyTeam/TeamStatusView.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo -n "CharacterReactionEventSink workflowCompleted observer: "
grep -c "workflowCompleted" MyTeam/CharacterReactionEventSink.swift && echo " (OK)" || echo "⚠ NOT FOUND"
echo ""

# MARK: - Sprite Handoff Docs
echo "== Sprite Handoff Documents =="
ls -la docs/character/ChikoSpriteSheetHandoff.md docs/character/CharacterSpriteRosterRoadmap.md docs/character/CharacterReactionDelegateDecision.md 2>/dev/null || echo "⚠ Some handoff docs missing"
echo ""

# MARK: - Character Planning Docs
echo "== Character Planning Docs =="
ls -la docs/character/CharacterReactionBridgeBacklog.md docs/character/SpriteSheetProductionSpec.md docs/character/CharacterReactionEnginePlan.md 2>/dev/null || echo "⚠ Some planning docs missing"
echo ""

# MARK: - Validator / BurnIn
echo "== ToolContractValidator / RouterBurnInSuite =="
ls -lh MyTeam/ToolContractValidator.swift MyTeam/RouterBurnInSuite.swift 2>/dev/null || echo "⚠ Validator/BurnIn files missing"
echo -n "Round 232 validators in ToolContractValidator: "
grep -c "validateCharacterSpriteSheetHandoffPolicy\|validateCharacterReactionDelegatePolicy\|validateCharacterSpriteRosterPolicy" MyTeam/ToolContractValidator.swift && echo " (OK)" || echo "⚠ Round 232 validators missing"
echo -n "Round 232 burn-in cases in RouterBurnInSuite: "
grep -c "character-reaction-workroom-opened\|character-reaction-document-generation\|character-reaction-artifact-created" MyTeam/RouterBurnInSuite.swift && echo " (OK)" || echo "⚠ Round 232 cases missing"
echo ""

# MARK: - Forbidden Privacy Copy (Swift 소스만)
echo "== Forbidden Privacy Copy (Swift sources only) =="
if grep -R "외부 서버 없음\|완전 로컬\|내 기기 안에서만\|어떤 데이터도 외부로 나가지\|서버 없음" MyTeam --include="*.swift" 2>/dev/null | grep -q .; then
    echo "⚠ Forbidden copy in Swift source:"
    grep -Rn "외부 서버 없음\|완전 로컬\|내 기기 안에서만\|어떤 데이터도 외부로 나가지\|서버 없음" MyTeam --include="*.swift" 2>/dev/null
else
    echo "✓ No misleading privacy copy in Swift sources"
fi
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
echo "Character Preflight Check Complete"
echo "=========================================="
