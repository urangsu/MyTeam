#!/usr/bin/env bash
# Round 263-CORE-CONVERSATION-RELIABILITY-GATE preflight
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0; total=0

check() {
    local label="$1"; shift
    total=$((total + 1))
    if "$@" 2>/dev/null; then
        pass=$((pass + 1)); echo "✅ [$total] $label"
    else
        echo "❌ [$total] $label"
    fi
}

fhas()  { grep -qF "$2" "$1"; }
fnot()  { ! grep -qF "$2" "$1"; }

AI="MyTeam/AIService.swift"
CM="MyTeam/ConversationMemory.swift"
AW="MyTeam/AgentWindowManager.swift"
AC="MyTeam/AgentChatView.swift"
TT="MyTeam/TeamTableView.swift"
TO="MyTeam/TeamOrchestrator.swift"

check "AIService providerCandidates 존재"         fhas "$AI" "providerCandidates"
check "AIService hasAPIKey 사용"                  fhas "$AI" "hasAPIKey"
check "AIService shouldFallbackProvider 존재"      fhas "$AI" "shouldFallbackProvider"
check "AIService streamForProvider 존재"           fhas "$AI" "streamForProvider"
check "OpenAI 응답 오류 처리"                      fhas "$AI" "OpenAI 응답 오류"
check "Claude 응답 오류 처리"                      fhas "$AI" "Claude 응답 오류"
check "OpenRouter 응답 오류 처리"                  fhas "$AI" "OpenRouter 응답 오류"
check "ConversationMemory promptHistory 존재"       fhas "$CM" "static func promptHistory"
check "promptHistory excludingMessageID 존재"       fhas "$CM" "excludingMessageID"
check "AgentWindowManager @discardableResult"       fhas "$AW" "@discardableResult"
check "AgentWindowManager updateChatLogText 존재"   fhas "$AW" "updateChatLogText"
check "PersonalChat userMessageID 캡처"             fhas "$AC" "let userMessageID = manager.addChatLog"
check "PersonalChat excludingMessageID 사용"        fhas "$AC" "excludingMessageID: userMessageID"
check "PersonalChat scopedMemoryContext 사용"       fhas "$AC" "scopedMemoryContext"
check "PersonalChat persistentContext 직접주입 제거" fnot "$AC" "manager.persistentContext"
check "PersonalChat ttsStream 분리"                fhas "$AC" "ttsStream"
check "PersonalChat TTS chunk 채팅저장 차단"        fnot "$AC" "text: chunk, isUser: false"
check "TeamTableView userMessageID 캡처"            fhas "$TT" "userMessageID"
check "TeamOrchestrator currentUserMessageID 존재"  fhas "$TO" "currentUserMessageID"
check "TeamOrchestrator excludingMessageID 사용"    fhas "$TO" "excludingMessageID"
check "TeamOrchestrator scoped room memory 사용"    fhas "$TO" "scopedMemoryContext"
check "ConversationReliabilityPolicy.md 존재"       test -f "docs/ConversationReliabilityPolicy.md"
check "round263 report 존재"                        test -f "reports/round263_conversation_reliability.md"

echo ""
echo "=============================="
echo "결과: ${pass}/${total} PASS"
if [ "$pass" -eq "$total" ]; then
    echo "🎉 ALL ${pass}/23 PASS — Round 263 preflight OK"
else
    echo "⚠️  $((total - pass))개 실패"
fi
