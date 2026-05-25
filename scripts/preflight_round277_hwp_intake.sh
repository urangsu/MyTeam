#!/bin/bash
# Round 277-KOREAN-HWP-INTAKE: HWP File Intake Preflight Verification
# Purpose: Verify HWP/HWPX file reading infrastructure implementation
# Run on: Any platform (cloud + Mac)
# Usage: bash scripts/preflight_round277_hwp_intake.sh
# Exit: 0 if all checks pass, 1 if any check fails

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo "=========================================="
echo "Round 277-KOREAN-HWP-INTAKE: Preflight Check"
echo "=========================================="
echo ""

# =============================================================================
# Part 1: Documentation Checks
# =============================================================================

echo "Part 1: Documentation"
echo "---"

if [ -f "$REPO_ROOT/docs/HWPFormatSpecification.md" ]; then
    check_pass "HWPFormatSpecification.md exists"
else
    check_fail "HWPFormatSpecification.md missing"
fi

if grep -q "HWP 파일 구조\|ZIP 기반" "$REPO_ROOT/docs/HWPFormatSpecification.md" 2>/dev/null; then
    check_pass "HWPFormatSpecification.md has content"
else
    check_fail "HWPFormatSpecification.md incomplete"
fi

# =============================================================================
# Part 2: Source Code Checks
# =============================================================================

echo ""
echo "Part 2: Source Code Structure"
echo "---"

# 1. HWPFileExtractor exists
if [ -f "$REPO_ROOT/MyTeam/HWPFileExtractor.swift" ]; then
    check_pass "HWPFileExtractor.swift exists"
else
    check_fail "HWPFileExtractor.swift missing"
fi

# 2. HWPFileExtractor has extract functions
if grep -q "extractText\|extractMarkdown" "$REPO_ROOT/MyTeam/HWPFileExtractor.swift" 2>/dev/null; then
    check_pass "HWPFileExtractor: extractText/extractMarkdown found"
else
    check_fail "HWPFileExtractor: extract functions missing"
fi

# 3. HWPFileExtractor has XML parser
if grep -q "HWPXMLParser\|XMLParserDelegate" "$REPO_ROOT/MyTeam/HWPFileExtractor.swift" 2>/dev/null; then
    check_pass "HWPFileExtractor: XML parser delegate found"
else
    check_fail "HWPFileExtractor: XML parser missing"
fi

# 4. HWPFileExtractor has ZIP unpacking
if grep -q "unpackArchive\|ZIPFoundation" "$REPO_ROOT/MyTeam/HWPFileExtractor.swift" 2>/dev/null; then
    check_pass "HWPFileExtractor: ZIP unpacking found"
else
    check_fail "HWPFileExtractor: ZIP unpacking missing"
fi

# 5. HWPFileExtractor has error handling
if grep -q "enum HWPExtractionError\|LocalizedError" "$REPO_ROOT/MyTeam/HWPFileExtractor.swift" 2>/dev/null; then
    check_pass "HWPFileExtractor: error handling found"
else
    check_fail "HWPFileExtractor: error handling missing"
fi

# 6. FileIntakeService has ingestHWP case
if grep -q "case \"hwp\", \"hwpx\"" "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: hwp/hwpx case added"
else
    check_fail "FileIntakeService: hwp/hwpx case missing"
fi

# 7. FileIntakeService has ingestHWP function
if grep -q "private static func ingestHWP" "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: ingestHWP function found"
else
    check_fail "FileIntakeService: ingestHWP function missing"
fi

# 8. FileIntakeService calls HWPFileExtractor
if grep -q "HWPFileExtractor.extractMarkdown" "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: HWPFileExtractor integration found"
else
    check_fail "FileIntakeService: HWPFileExtractor integration missing"
fi

# 9. FileIntakePolicy allows hwp/hwpx
if grep -q '"hwp", "hwpx"' "$REPO_ROOT/MyTeam/FileIntakePolicy.swift" 2>/dev/null || \
   grep -q '"hwp".*"hwpx"' "$REPO_ROOT/MyTeam/FileIntakePolicy.swift" 2>/dev/null; then
    check_pass "FileIntakePolicy: hwp/hwpx in readableExtensions"
else
    check_fail "FileIntakePolicy: hwp/hwpx not in readableExtensions"
fi

# 10. HWPFileExtractor has Sendable conformance
if grep -q "struct HWPParagraph.*Sendable" "$REPO_ROOT/MyTeam/HWPFileExtractor.swift" 2>/dev/null; then
    check_pass "HWPFileExtractor: HWPParagraph is Sendable"
else
    check_fail "HWPFileExtractor: HWPParagraph Sendable missing"
fi

# 11. HWPFileExtractor error enum is Sendable
if grep -q "enum HWPExtractionError.*Sendable" "$REPO_ROOT/MyTeam/HWPFileExtractor.swift" 2>/dev/null; then
    check_pass "HWPFileExtractor: error enum is Sendable"
else
    check_fail "HWPFileExtractor: error enum Sendable missing"
fi

# 12. FileIntakeService imports ZIPFoundation (for HWP support)
if grep -q "import ZIPFoundation" "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: ZIPFoundation import present"
else
    check_fail "FileIntakeService: ZIPFoundation import missing"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "Round 277 Preflight Summary"
echo "=========================================="

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Checks: $TOTAL total"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All checks passed! ✅${NC}"
    echo "HWP/HWPX file intake infrastructure ready."
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. See details above.${NC}"
    exit 1
fi
