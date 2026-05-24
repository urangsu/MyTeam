#!/usr/bin/env bash
# preflight_round271_edge_tuck_router_context.sh
# Round 271: Edge tuck + router/context integrity gate

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/MyTeam"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
fhas() { grep -qF "$1" "$2" 2>/dev/null; }
fnot() { ! grep -qF "$1" "$2" 2>/dev/null; }

echo "=== Round 271 EDGE-TUCK / ROUTER / CONTEXT Preflight ==="
echo

if fhas "enum PanelTuckState" "$SRC/FloatingPanel.swift" && fhas "enum PanelTuckEdge" "$SRC/FloatingPanel.swift"; then
    ok "FloatingPanel PanelTuckState/PanelTuckEdge 존재"
else
    fail "PanelTuckState/PanelTuckEdge 없음"
fi

if fhas 'agentID != "team"' "$SRC/FloatingPanel.swift"; then
    ok "team 패널 edge tuck 제외"
else
    fail "team 패널 제외 로직 없음"
fi

for id in chat_single status_window settings_window agent_settings_window swap_window; do
    if fhas "\"$id\"" "$SRC/FloatingPanel.swift"; then
        ok "edge tuck 대상 패널 등록: $id"
    else
        fail "edge tuck 대상 누락: $id"
    fi
done

if ! grep -A8 'case \.openAI' "$SRC/AIService.swift" | grep -q 'AIModelPolicy.resolvedModelID'; then
    ok "OpenAI stream discovery 우회용 pre-resolved pinned model 전달 없음"
else
    fail "OpenAI stream에 pre-resolved model 전달 잔존"
fi

if fhas "resolveLLMCall(" "$SRC/AIService.swift" && fhas "resolvedCall.modelID" "$SRC/AIService.swift"; then
    ok "ResolvedLLMCall production metadata 경로 사용"
else
    fail "ResolvedLLMCall production 경로 미사용"
fi

if fnot "ToolNeedClassifier.needsTool(groundedText" "$SRC/AgentChatView.swift"; then
    ok "ToolNeedClassifier groundedText 검사 금지"
else
    fail "ToolNeedClassifier가 groundedText를 검사함"
fi

if fhas "RoomContextBuilder.build(manager: manager, roomID:" "$ROOT/MyTeamTests/LLMRouterTests.swift"; then
    ok "RoomContextBuilder 실제 manager 기반 XCTest 존재"
else
    fail "RoomContextBuilder 실제 builder XCTest 없음"
fi

if fnot "if roomID == currentRoomID" "$SRC/AgentWindowManager.swift"; then
    ok "recentArtifacts currentRoom global fallback 제거"
else
    fail "recentArtifacts currentRoom global fallback 잔존"
fi

if fhas "trustStrip" "$SRC/WorkroomHomeView.swift"; then
    ok "Workroom Trust Strip 존재"
else
    fail "Workroom Trust Strip 없음"
fi

ROOT_SPIKES=0
while IFS= read -r file; do
    base="$(basename "$file")"
    echo "    root spike executable: $base"
    ROOT_SPIKES=$((ROOT_SPIKES+1))
done < <(find "$ROOT" -maxdepth 1 -type f -name 'test_*' -perm -111)

if [ "$ROOT_SPIKES" -eq 0 ]; then
    ok "root test_* 실행 파일 없음"
else
    fail "root test_* 실행 파일 ${ROOT_SPIKES}개"
fi

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
