#!/bin/bash
# Round 279-FILEINTAKE-EXPANSION Phase 1C: DOCX File Intake Preflight
# Purpose: Verify DOCX extraction infrastructure
# Usage: bash scripts/preflight_round279_docx_intake.sh
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
echo "Round 279-FILEINTAKE-EXPANSION Phase 1C: DOCX Intake"
echo "=========================================="
echo ""

echo "Part 1: Source Code"
echo "---"

# 1. DOCXFileExtractor exists
if [ -f "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" ]; then
    check_pass "DOCXFileExtractor.swift exists"
else
    check_fail "DOCXFileExtractor.swift missing"
fi

# 2. Extract functions
if grep -q "extractText\|extractMarkdown" "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" 2>/dev/null; then
    check_pass "DOCXFileExtractor: extract functions found"
else
    check_fail "DOCXFileExtractor: extract functions missing"
fi

# 3. DOCXParagraph struct
if grep -q "struct DOCXParagraph" "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" 2>/dev/null; then
    check_pass "DOCXFileExtractor: DOCXParagraph struct found"
else
    check_fail "DOCXFileExtractor: DOCXParagraph missing"
fi

# 4. Error handling
if grep -q "enum DOCXExtractionError\|LocalizedError" "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" 2>/dev/null; then
    check_pass "DOCXFileExtractor: error handling found"
else
    check_fail "DOCXFileExtractor: error handling missing"
fi

# 5. ZIPFoundation usage
if grep -q "import ZIPFoundation\|Archive" "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" 2>/dev/null; then
    check_pass "DOCXFileExtractor: ZIPFoundation usage found"
else
    check_fail "DOCXFileExtractor: ZIPFoundation missing"
fi

# 6. FileIntakeService integration
if grep -q "DOCXFileExtractor.extractMarkdown\|ext == \"docx\"" "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: DOCX integration found"
else
    check_fail "FileIntakeService: DOCX integration missing"
fi

# 7. FileIntakePolicy docx support
if grep -q '"docx"' "$REPO_ROOT/MyTeam/FileIntakePolicy.swift" 2>/dev/null; then
    check_pass "FileIntakePolicy: docx in readable extensions"
else
    check_fail "FileIntakePolicy: docx not in readable"
fi

# 8. Paragraph struct Sendable
if grep -q "struct DOCXParagraph.*Sendable" "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" 2>/dev/null; then
    check_pass "DOCXFileExtractor: DOCXParagraph is Sendable"
else
    check_fail "DOCXFileExtractor: Sendable missing"
fi

# 9. Error enum Sendable
if grep -q "enum DOCXExtractionError.*Sendable" "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" 2>/dev/null; then
    check_pass "DOCXFileExtractor: error enum is Sendable"
else
    check_fail "DOCXFileExtractor: error Sendable missing"
fi

# 10. XML parsing
if grep -q "XMLParser\|XMLParserDelegate" "$REPO_ROOT/MyTeam/DOCXFileExtractor.swift" 2>/dev/null; then
    check_pass "DOCXFileExtractor: XML parsing found"
else
    check_fail "DOCXFileExtractor: XML parsing missing"
fi

echo ""
echo "=========================================="
echo "Round 279 Phase 1C Preflight Summary"
echo "=========================================="

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Checks: $TOTAL total"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All checks passed! ✅${NC}"
    echo "DOCX file intake infrastructure ready."
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. See details above.${NC}"
    exit 1
fi
