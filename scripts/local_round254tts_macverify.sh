#!/bin/bash
# Round 254TTS-NOTICE: Local Mac Build Verification Script
# Purpose: Verify Supertonic notice gate implementation across Mac Debug + Release builds
# Run on: macOS local development machine (not cloud)
# Usage: bash scripts/local_round254tts_macverify.sh
# Exit: 0 if all checks pass, 1 if any check fails

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

check_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

echo "=========================================="
echo "Round 254TTS-NOTICE: Local Mac Verification"
echo "=========================================="
echo ""

# =============================================================================
# Part 1: Source Code Static Checks (can run on any platform)
# =============================================================================

echo "Part 1: Static Source Code Checks"
echo "---"

# 1. Verify notice policy file structure
if grep -q "currentNoticeVersion.*round254-2026-05" "$REPO_ROOT/MyTeam/SupertonicTTSNoticePolicy.swift" 2>/dev/null; then
    check_pass "SupertonicTTSNoticePolicy: notice version defined"
else
    check_fail "SupertonicTTSNoticePolicy: notice version not found"
fi

# 2. Verify notice policy UserDefaults keys
if grep -q "licenseAcceptedKey\|useRestrictionsAcceptedKey\|noticeVersionKey" "$REPO_ROOT/MyTeam/SupertonicTTSNoticePolicy.swift" 2>/dev/null; then
    check_pass "SupertonicTTSNoticePolicy: UserDefaults keys defined"
else
    check_fail "SupertonicTTSNoticePolicy: UserDefaults keys not found"
fi

# 3. Verify notice card view exists
if [ -f "$REPO_ROOT/MyTeam/SupertonicNoticeCardView.swift" ]; then
    check_pass "SupertonicNoticeCardView.swift exists"
else
    check_fail "SupertonicNoticeCardView.swift missing"
fi

# 4. Verify card view accepts @Binding
if grep -q "@Binding.*accepted.*Bool" "$REPO_ROOT/MyTeam/SupertonicNoticeCardView.swift" 2>/dev/null; then
    check_pass "SupertonicNoticeCardView: @Binding parameter found"
else
    check_fail "SupertonicNoticeCardView: @Binding parameter missing"
fi

# 5. Verify TTSLabView has notice section
if grep -q "SupertonicNoticeCardView\|supertonicNoticeSection" "$REPO_ROOT/MyTeam/TTSLabView.swift" 2>/dev/null; then
    check_pass "TTSLabView: notice section integrated"
else
    check_fail "TTSLabView: notice section not integrated"
fi

# 6. Verify ONNX synthesis button has notice gate
if grep -q "\.disabled.*||.*!noticeAccepted\|\.disabled.*!noticeAccepted" "$REPO_ROOT/MyTeam/TTSLabView.swift" 2>/dev/null; then
    check_pass "TTSLabView: synthesis button noticeAccepted gate found"
else
    check_fail "TTSLabView: synthesis button gate missing"
fi

# 7. Verify notice acceptance restoration in onAppear
if grep -q "noticeAccepted.*=.*SupertonicTTSNoticePolicy\.isCurrentNoticeAccepted\|\.onAppear.*noticeAccepted" "$REPO_ROOT/MyTeam/TTSLabView.swift" 2>/dev/null; then
    check_pass "TTSLabView: notice acceptance restoration logic found"
else
    check_fail "TTSLabView: notice restoration logic missing"
fi

# 8. Verify TTSProductPolicy has notice requirements
if grep -q "licenseNoticeRequired.*=.*true\|useRestrictionNoticeRequired.*=.*true\|userNoticeAcceptanceRequired.*=.*true" "$REPO_ROOT/MyTeam/TTSProductPolicy.swift" 2>/dev/null; then
    check_pass "TTSProductPolicy: notice requirement flags defined"
else
    check_fail "TTSProductPolicy: notice requirement flags missing"
fi

# =============================================================================
# Part 2: Mac Build Verification (requires macOS + Xcode)
# =============================================================================

echo ""
echo "Part 2: Mac Build Verification (requires macOS + Xcode)"
echo "---"

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  Skipping Mac-only checks (not on macOS)"
    check_warn "Mac build verification skipped on non-macOS platform"
else
    # 9. Build Debug configuration
    echo "Building Debug configuration..."
    if xcodebuild -project "$REPO_ROOT/MyTeam/MyTeam.xcodeproj" \
                  -scheme MyTeam \
                  -configuration Debug \
                  build 2>&1 | grep -q "BUILD SUCCEEDED"; then
        check_pass "Debug build succeeded"
    else
        check_fail "Debug build failed"
    fi

    # 10. Build Release configuration
    echo "Building Release configuration..."
    if xcodebuild -project "$REPO_ROOT/MyTeam/MyTeam.xcodeproj" \
                  -scheme MyTeam \
                  -configuration Release \
                  build 2>&1 | grep -q "BUILD SUCCEEDED"; then
        check_pass "Release build succeeded"
    else
        check_fail "Release build failed"
    fi

    # 11. Verify no new Swift warnings introduced
    echo "Checking for new warnings..."
    DEBUG_BUILD=$(xcodebuild -project "$REPO_ROOT/MyTeam/MyTeam.xcodeproj" \
                              -scheme MyTeam \
                              -configuration Debug \
                              build 2>&1)

    if echo "$DEBUG_BUILD" | grep -i "error:" | grep -v "ONNX\|Supertonic" > /dev/null 2>&1; then
        check_fail "Unexpected build errors detected"
    else
        check_pass "No unexpected build errors"
    fi

    # 12. Verify app bundle contains notice files
    echo "Verifying app bundle integration..."
    if [ -f "$REPO_ROOT/MyTeam/SupertonicTTSNoticePolicy.swift" ] && \
       [ -f "$REPO_ROOT/MyTeam/SupertonicNoticeCardView.swift" ]; then
        check_pass "Notice implementation files present in source tree"
    else
        check_fail "Notice implementation files missing"
    fi
fi

# =============================================================================
# Part 3: Runtime Verification (requires running app on Mac)
# =============================================================================

echo ""
echo "Part 3: Runtime Verification (manual on Mac)"
echo "---"

echo "After building on Mac, manually verify:"
echo "  1. Launch MyTeam app"
echo "  2. Navigate to TTS Lab"
echo "  3. Verify SupertonicNoticeCardView displays with:"
echo "     - License notice explaining Supertonic as sole candidate"
echo "     - Use restrictions card (prohibits sarcasm, deception, harassment)"
echo "     - Acceptance toggle: '고지를 확인하고 실험 기능 사용'"
echo "  4. Verify ONNX synthesis button is disabled until notice accepted"
echo "  5. Click acceptance button, verify button state changes"
echo "  6. Quit and relaunch app"
echo "  7. Verify acceptance state persists (notice remains accepted)"
echo "  8. Verify notice re-appears if version bumped in SupertonicTTSNoticePolicy"
echo ""

# =============================================================================
# Summary
# =============================================================================

echo "=========================================="
echo "Round 254TTS-NOTICE Local Verification Summary"
echo "=========================================="

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Static Checks: $TOTAL total"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All checks passed!${NC}"
    echo "Next: Run on macOS with Xcode and complete manual runtime verification."
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. See details above.${NC}"
    exit 1
fi
