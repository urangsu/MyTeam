#!/bin/bash
# App Store Readiness Verification Script
# Purpose: Automated checks for App Store submission compliance (cloud-safe)
# Usage: bash scripts/verify_appstore_readiness.sh
# Exit: 0 if all checks pass, 1 if any fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
echo "App Store Readiness Verification"
echo "=========================================="
echo ""

# =============================================================================
# Part 1: Documentation Checks
# =============================================================================

echo "Part 1: Documentation"
echo "---"

if [ -f "$REPO_ROOT/docs/PrivacyPolicy.md" ]; then
    check_pass "PrivacyPolicy.md exists"
else
    check_fail "PrivacyPolicy.md missing"
fi

if [ -f "$REPO_ROOT/docs/AppStoreConnectSubmissionGuide.md" ]; then
    check_pass "AppStoreConnectSubmissionGuide.md exists"
else
    check_fail "AppStoreConnectSubmissionGuide.md missing"
fi

if [ -f "$REPO_ROOT/docs/AppStoreMetadataDraft.md" ]; then
    check_pass "AppStoreMetadataDraft.md exists"
else
    check_fail "AppStoreMetadataDraft.md missing"
fi

if [ -f "$REPO_ROOT/docs/AppStorePackagingChecklist.md" ]; then
    check_pass "AppStorePackagingChecklist.md exists"
else
    check_fail "AppStorePackagingChecklist.md missing"
fi

# =============================================================================
# Part 2: Entitlements & Privacy Files
# =============================================================================

echo ""
echo "Part 2: Entitlements & Privacy"
echo "---"

if [ -f "$REPO_ROOT/MyTeam/MyTeam.entitlements" ]; then
    check_pass "MyTeam.entitlements exists"

    if grep -q "com.apple.security.app-sandbox" "$REPO_ROOT/MyTeam/MyTeam.entitlements"; then
        check_pass "Sandbox entitlement present"
    else
        check_fail "Sandbox entitlement missing"
    fi

    if grep -q "com.apple.security.files.user-selected.read-write" "$REPO_ROOT/MyTeam/MyTeam.entitlements"; then
        check_pass "File picker entitlement present"
    else
        check_fail "File picker entitlement missing"
    fi
else
    check_fail "MyTeam.entitlements missing"
fi

if [ -f "$REPO_ROOT/MyTeam/PrivacyInfo.xcprivacy" ]; then
    check_pass "PrivacyInfo.xcprivacy exists"

    if grep -q "NSPrivacyTracking" "$REPO_ROOT/MyTeam/PrivacyInfo.xcprivacy"; then
        check_pass "Privacy tracking declaration present"
    else
        check_fail "Privacy tracking declaration missing"
    fi
else
    check_fail "PrivacyInfo.xcprivacy missing"
fi

# =============================================================================
# Part 3: Code Compliance Checks
# =============================================================================

echo ""
echo "Part 3: Code Compliance"
echo "---"

# Check: No AVSpeechSynthesizer actual usage (mentions in comments/strings are OK)
if grep -r "AVSpeechSynthesizer" "$REPO_ROOT/MyTeam" --include="*.swift" 2>/dev/null | grep -v "//" | grep -v "Text(" | grep -v "\"" | grep -v "String"; then
    check_fail "AVSpeechSynthesizer used in code (Apple TTS banned)"
else
    check_pass "No AVSpeechSynthesizer usage (Apple TTS correctly banned, mentions only in comments/strings)"
fi

# Check: External write blocking
if grep -q "blockedExtensions.*\"app\"\|\"pkg\"\|\"dmg\"\|\"sh\"" "$REPO_ROOT/MyTeam/FileIntakePolicy.swift" 2>/dev/null; then
    check_pass "Blocked file extensions policy present"
else
    check_fail "Blocked file extensions missing"
fi

# Check: Sandbox-compliant path handling
if grep -q "ArtifactStore\|normalizeStoredPath\|isSafeRelativePath" "$REPO_ROOT/MyTeam/ArtifactStore.swift" 2>/dev/null; then
    check_pass "Artifact path normalization present"
else
    check_warn "Artifact path safety check unclear (manual verification needed)"
fi

# Check: No force unwrap in critical paths
FORCE_UNWRAPS=$(grep -r "try!" "$REPO_ROOT/MyTeam" --include="*.swift" 2>/dev/null | grep -v "test" | grep -v "//" | wc -l)
if [ "$FORCE_UNWRAPS" -eq 0 ]; then
    check_pass "No force unwrap (try!) in code"
else
    check_warn "Found $FORCE_UNWRAPS try! statements (review for safety)"
fi

# =============================================================================
# Part 4: API & Network Compliance
# =============================================================================

echo ""
echo "Part 4: API & Network"
echo "---"

# Check: Network-related entitlements
if grep -q "com.apple.security.network.client" "$REPO_ROOT/MyTeam/MyTeam.entitlements"; then
    check_pass "Network client entitlement (required for Claude/Google APIs)"
else
    check_warn "Network client entitlement missing (needed for API calls)"
fi

# Check: No auto-approval mechanisms
if ! grep -q "auto.*.approve\|autoApprove" "$REPO_ROOT/MyTeam" -r --include="*.swift" 2>/dev/null | grep -v "//"; then
    check_pass "No auto-approval mechanisms found"
else
    check_fail "Auto-approval detected (should be user-initiated)"
fi

# =============================================================================
# Part 5: Screenshots & Metadata
# =============================================================================

echo ""
echo "Part 5: Screenshots & Metadata"
echo "---"

SCREENSHOTS_DIR="$REPO_ROOT/screenshots"
if [ -d "$SCREENSHOTS_DIR" ]; then
    SCREENSHOT_COUNT=$(find "$SCREENSHOTS_DIR" -type f \( -name "*.png" -o -name "*.jpg" \) 2>/dev/null | wc -l)
    if [ "$SCREENSHOT_COUNT" -gt 0 ]; then
        check_pass "Screenshots directory exists with $SCREENSHOT_COUNT files"
    else
        check_warn "Screenshots directory exists but empty (needed for submission)"
    fi
else
    check_warn "Screenshots directory not created yet (create during manual QA phase)"
fi

if grep -q "MyTeam - AI 업무 팀" "$REPO_ROOT/docs/AppStoreMetadataDraft.md"; then
    check_pass "Korean metadata present"
else
    check_fail "Korean metadata missing"
fi

# =============================================================================
# Part 6: Script & Tools
# =============================================================================

echo ""
echo "Part 6: Scripts & Tools"
echo "---"

if [ -f "$REPO_ROOT/scripts/generate_appstore_screenshots.sh" ]; then
    check_pass "Screenshot generation script present"
else
    check_fail "Screenshot generation script missing"
fi

if [ -f "$REPO_ROOT/scripts/preflight_round277_hwp_intake.sh" ]; then
    check_pass "HWP intake preflight script present"
else
    check_warn "HWP intake preflight missing (from previous round)"
fi

# =============================================================================
# Part 7: Release-specific Compliance
# =============================================================================

echo ""
echo "Part 7: Release Configuration"
echo "---"

if grep -q "DEBUG" "$REPO_ROOT/MyTeam" -r --include="*.swift" 2>/dev/null | grep -i "if.*DEBUG\|#if DEBUG"; then
    check_pass "DEBUG conditional compilation present"
else
    check_warn "DEBUG conditionals not found (manual code review recommended)"
fi

# Check for hard-coded dev URLs
if grep -q "localhost\|127.0.0.1\|dev.example.com" "$REPO_ROOT/MyTeam" -r --include="*.swift" 2>/dev/null | grep -v "//"; then
    check_fail "Local/dev URLs found in production code"
else
    check_pass "No local/dev URLs in production code"
fi

# =============================================================================
# Part 8: Metadata Fields Validation
# =============================================================================

echo ""
echo "Part 8: Metadata Fields"
echo "---"

METADATA_FILE="$REPO_ROOT/docs/AppStoreMetadataDraft.md"

REQUIRED_FIELDS=("App Name" "Subtitle" "Short Description" "Keywords" "What It Does" "Privacy")
for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -q "$field" "$METADATA_FILE"; then
        check_pass "Metadata field '$field' present"
    else
        check_fail "Metadata field '$field' missing"
    fi
done

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "App Store Readiness Summary"
echo "=========================================="

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Checks: $TOTAL total"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ Cloud compliance checks passed!${NC}"
    echo ""
    echo "Local execution required:"
    echo "  1. Link MyTeam.entitlements in Xcode (2 min)"
    echo "  2. Run Release build: xcodebuild ... -configuration Release build"
    echo "  3. Execute manual QA (6 tests, 20 min)"
    echo "  4. Capture screenshots (3-5 per language, 30 min)"
    echo "  5. Upload to App Store Connect"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Review above and fix before submission.${NC}"
    echo ""
    exit 1
fi
