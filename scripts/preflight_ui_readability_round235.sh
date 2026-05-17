#!/usr/bin/env bash
# preflight_ui_readability_round235.sh
# Round 235: UI Readability Tokens + Agent Chat Switching validation
# Run from repo root: bash scripts/preflight_ui_readability_round235.sh

set -euo pipefail
PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "ok" ]; then
        echo "  ✅  $desc"
        PASS=$((PASS+1))
    else
        echo "  ❌  $desc — $result"
        FAIL=$((FAIL+1))
    fi
}

echo ""
echo "=== Round 235 UI Readability Preflight ==="
echo ""

# 1. Color token file has mtTextPrimary
grep -q "mtTextPrimary" "$REPO_ROOT/MyTeam/MyTeam/Color+Hex.swift" \
    && check "Color+Hex.swift has mtTextPrimary token" "ok" \
    || check "Color+Hex.swift has mtTextPrimary token" "not found"

# 2. Color token file has mtInputBackground
grep -q "mtInputBackground" "$REPO_ROOT/MyTeam/MyTeam/Color+Hex.swift" \
    && check "Color+Hex.swift has mtInputBackground token" "ok" \
    || check "Color+Hex.swift has mtInputBackground token" "not found"

# 3. AgentWindowManager has openPersonalChat
grep -q "func openPersonalChat" "$REPO_ROOT/MyTeam/MyTeam/AgentWindowManager.swift" \
    && check "AgentWindowManager has openPersonalChat(for:)" "ok" \
    || check "AgentWindowManager has openPersonalChat(for:)" "not found"

# 4. TeamTableView wires openPersonalChat on agent tap
grep -q "openPersonalChat" "$REPO_ROOT/MyTeam/MyTeam/TeamTableView.swift" \
    && check "TeamTableView wires openPersonalChat on tap" "ok" \
    || check "TeamTableView wires openPersonalChat on tap" "not found"

# 5. TeamStatusView wires openPersonalChat on agent row tap
grep -q "openPersonalChat" "$REPO_ROOT/MyTeam/MyTeam/TeamStatusView.swift" \
    && check "TeamStatusView wires openPersonalChat on agent row tap" "ok" \
    || check "TeamStatusView wires openPersonalChat on agent row tap" "not found"

# 6. No dangerously low opacity (< 0.05) directly on text foreground in main chat area
# (warn only — not a hard fail since some uses are intentional for decorative elements)
COUNT=$(grep -n "foregroundColor.*opacity(0\.0[1-4])" "$REPO_ROOT/MyTeam/MyTeam/TeamStatusView.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
    check "No sub-0.05 opacity foregroundColor in TeamStatusView" "ok"
else
    check "No sub-0.05 opacity foregroundColor in TeamStatusView" "found $COUNT instances (review manually)"
fi

# 7. BeginnerTaskCardView uses mtCardBackground
grep -q "mtCardBackground" "$REPO_ROOT/MyTeam/MyTeam/BeginnerTaskCardView.swift" \
    && check "BeginnerTaskCardView uses mtCardBackground" "ok" \
    || check "BeginnerTaskCardView uses mtCardBackground" "not found"

# 8. WorkroomHomeView uses mtCardBackground
grep -q "mtCardBackground" "$REPO_ROOT/MyTeam/MyTeam/WorkroomHomeView.swift" \
    && check "WorkroomHomeView uses mtCardBackground" "ok" \
    || check "WorkroomHomeView uses mtCardBackground" "not found"

# 9. AgentChatView inputBgColor uses mtInputBackground
grep -q "mtInputBackground" "$REPO_ROOT/MyTeam/MyTeam/AgentChatView.swift" \
    && check "AgentChatView inputBgColor uses mtInputBackground" "ok" \
    || check "AgentChatView inputBgColor uses mtInputBackground" "not found"

# 10. RuntimeDiagnostics has Round 235 fields
grep -q "chatReadabilityTokensAvailable" "$REPO_ROOT/MyTeam/MyTeam/RuntimeDiagnosticsService.swift" \
    && check "RuntimeDiagnosticsService has Round 235 fields" "ok" \
    || check "RuntimeDiagnosticsService has Round 235 fields" "not found"

echo ""
echo "--- Build checks ---"
echo ""

# 11. Debug build
echo "  Running Debug build..."
if xcodebuild -project "$REPO_ROOT/MyTeam/MyTeam.xcodeproj" -scheme MyTeam -configuration Debug build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -q "BUILD SUCCEEDED"; then
    check "Debug build" "ok"
else
    check "Debug build" "FAILED"
fi

# 12. Release build
echo "  Running Release build..."
if xcodebuild -project "$REPO_ROOT/MyTeam/MyTeam.xcodeproj" -scheme MyTeam -configuration Release build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | grep -q "BUILD SUCCEEDED"; then
    check "Release build" "ok"
else
    check "Release build" "FAILED"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo "Preflight passed. Manual QA pending."
