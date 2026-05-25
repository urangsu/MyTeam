#!/bin/bash
# Round 279-FILEINTAKE-EXPANSION Phase 1B: XLSX File Intake Preflight
# Purpose: Verify XLSX extraction infrastructure
# Usage: bash scripts/preflight_round279_xlsx_intake.sh
# Exit: 0 if all checks pass, 1 if any fails

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
echo "Round 279-FILEINTAKE-EXPANSION Phase 1B: XLSX Intake"
echo "=========================================="
echo ""

# =============================================================================
# Part 1: Documentation Checks
# =============================================================================

echo "Part 1: Documentation"
echo "---"

if [ -f "$REPO_ROOT/docs/XLSXFileIntakeSpecification.md" ]; then
    check_pass "XLSXFileIntakeSpecification.md exists"
else
    check_fail "XLSXFileIntakeSpecification.md missing"
fi

if grep -q "XLSX\|worksheet\|extractMarkdown" "$REPO_ROOT/docs/XLSXFileIntakeSpecification.md" 2>/dev/null; then
    check_pass "XLSXFileIntakeSpecification.md has content"
else
    check_fail "XLSXFileIntakeSpecification.md incomplete"
fi

# =============================================================================
# Part 2: Source Code Checks
# =============================================================================

echo ""
echo "Part 2: Source Code Structure"
echo "---"

# 1. XLSXFileExtractor exists
if [ -f "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" ]; then
    check_pass "XLSXFileExtractor.swift exists"
else
    check_fail "XLSXFileExtractor.swift missing"
fi

# 2. Extract functions
if grep -q "extractText\|extractMarkdown" "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" 2>/dev/null; then
    check_pass "XLSXFileExtractor: extract functions found"
else
    check_fail "XLSXFileExtractor: extract functions missing"
fi

# 3. XLSXWorksheet struct
if grep -q "struct XLSXWorksheet" "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" 2>/dev/null; then
    check_pass "XLSXFileExtractor: XLSXWorksheet struct found"
else
    check_fail "XLSXFileExtractor: XLSXWorksheet missing"
fi

# 4. Error handling
if grep -q "enum XLSXExtractionError\|LocalizedError" "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" 2>/dev/null; then
    check_pass "XLSXFileExtractor: error handling found"
else
    check_fail "XLSXFileExtractor: error handling missing"
fi

# 5. ZIPFoundation usage
if grep -q "import ZIPFoundation\|Archive" "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" 2>/dev/null; then
    check_pass "XLSXFileExtractor: ZIPFoundation usage found"
else
    check_fail "XLSXFileExtractor: ZIPFoundation missing"
fi

# 6. FileIntakeService integration
if grep -q "XLSXFileExtractor.extractMarkdown\|ext == \"xlsx\"" "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: XLSX integration found"
else
    check_fail "FileIntakeService: XLSX integration missing"
fi

# 7. FileIntakePolicy xlsx support
if grep -q '"xlsx"' "$REPO_ROOT/MyTeam/FileIntakePolicy.swift" 2>/dev/null | head -1; then
    check_pass "FileIntakePolicy: xlsx in readable extensions"
else
    check_fail "FileIntakePolicy: xlsx not in readable"
fi

# 8. XML parsing
if grep -q "XMLParser\|XMLParserDelegate" "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" 2>/dev/null; then
    check_pass "XLSXFileExtractor: XML parsing found"
else
    check_fail "XLSXFileExtractor: XML parsing missing"
fi

# 9. Worksheet struct Sendable
if grep -q "struct XLSXWorksheet.*Sendable\|XLSXWorksheet.*Sendable" "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" 2>/dev/null; then
    check_pass "XLSXFileExtractor: XLSXWorksheet is Sendable"
else
    check_fail "XLSXFileExtractor: Sendable missing"
fi

# 10. Error enum Sendable
if grep -q "enum XLSXExtractionError.*Sendable" "$REPO_ROOT/MyTeam/XLSXFileExtractor.swift" 2>/dev/null; then
    check_pass "XLSXFileExtractor: error enum is Sendable"
else
    check_fail "XLSXFileExtractor: error Sendable missing"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "Round 279 Phase 1B Preflight Summary"
echo "=========================================="

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Checks: $TOTAL total"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All checks passed! ✅${NC}"
    echo "XLSX file intake infrastructure ready."
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. See details above.${NC}"
    exit 1
fi
