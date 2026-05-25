#!/bin/bash
# Round 279-FILEINTAKE-EXPANSION Phase 1A: PDF File Intake Preflight Verification
# Purpose: Verify PDF reading infrastructure implementation
# Run on: Cloud (no PDF files needed for static checks)
# Usage: bash scripts/preflight_round279_pdf_intake.sh
# Exit: 0 if all checks pass, 1 if any check fails

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
echo "Round 279-FILEINTAKE-EXPANSION Phase 1A: PDF Intake"
echo "=========================================="
echo ""

# =============================================================================
# Part 1: Documentation Checks
# =============================================================================

echo "Part 1: Documentation"
echo "---"

if [ -f "$REPO_ROOT/docs/PDFFileIntakeSpecification.md" ]; then
    check_pass "PDFFileIntakeSpecification.md exists"
else
    check_fail "PDFFileIntakeSpecification.md missing"
fi

if grep -q "PDF 파일\|extractMarkdown\|PDFDocument" "$REPO_ROOT/docs/PDFFileIntakeSpecification.md" 2>/dev/null; then
    check_pass "PDFFileIntakeSpecification.md has content"
else
    check_fail "PDFFileIntakeSpecification.md incomplete"
fi

# =============================================================================
# Part 2: Source Code Checks
# =============================================================================

echo ""
echo "Part 2: Source Code Structure"
echo "---"

# 1. PDFFileExtractor exists
if [ -f "$REPO_ROOT/MyTeam/PDFFileExtractor.swift" ]; then
    check_pass "PDFFileExtractor.swift exists"
else
    check_fail "PDFFileExtractor.swift missing"
fi

# 2. PDFFileExtractor has extract functions
if grep -q "extractText\|extractMarkdown" "$REPO_ROOT/MyTeam/PDFFileExtractor.swift" 2>/dev/null; then
    check_pass "PDFFileExtractor: extractText/extractMarkdown found"
else
    check_fail "PDFFileExtractor: extract functions missing"
fi

# 3. PDFFileExtractor has PDFPage struct
if grep -q "struct PDFPage" "$REPO_ROOT/MyTeam/PDFFileExtractor.swift" 2>/dev/null; then
    check_pass "PDFFileExtractor: PDFPage struct found"
else
    check_fail "PDFFileExtractor: PDFPage struct missing"
fi

# 4. PDFFileExtractor has error handling
if grep -q "enum PDFExtractionError\|LocalizedError" "$REPO_ROOT/MyTeam/PDFFileExtractor.swift" 2>/dev/null; then
    check_pass "PDFFileExtractor: error handling found"
else
    check_fail "PDFFileExtractor: error handling missing"
fi

# 5. PDFFileExtractor uses PDFKit
if grep -q "import PDFKit\|PDFDocument" "$REPO_ROOT/MyTeam/PDFFileExtractor.swift" 2>/dev/null; then
    check_pass "PDFFileExtractor: PDFKit usage found"
else
    check_fail "PDFFileExtractor: PDFKit missing"
fi

# 6. FileIntakeService integrates PDFFileExtractor
if grep -q "PDFFileExtractor.extractMarkdown" "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: PDFFileExtractor integration found"
else
    check_fail "FileIntakeService: PDFFileExtractor integration missing"
fi

# 7. FileIntakeService has pdf case
if grep -q 'ext == "pdf"' "$REPO_ROOT/MyTeam/FileIntakeService.swift" 2>/dev/null; then
    check_pass "FileIntakeService: pdf case handling found"
else
    check_fail "FileIntakeService: pdf case missing"
fi

# 8. FileIntakePolicy allows pdf
if grep -q '"pdf"' "$REPO_ROOT/MyTeam/FileIntakePolicy.swift" 2>/dev/null | head -1; then
    check_pass "FileIntakePolicy: pdf in readableExtensions"
else
    check_fail "FileIntakePolicy: pdf not in readableExtensions"
fi

# 9. PDFFileExtractor has Sendable conformance
if grep -q "struct PDFPage.*Sendable\|PDFPage.*Sendable" "$REPO_ROOT/MyTeam/PDFFileExtractor.swift" 2>/dev/null; then
    check_pass "PDFFileExtractor: PDFPage is Sendable"
else
    check_fail "PDFFileExtractor: PDFPage Sendable missing"
fi

# 10. PDFFileExtractor error enum is Sendable
if grep -q "enum PDFExtractionError.*Sendable" "$REPO_ROOT/MyTeam/PDFFileExtractor.swift" 2>/dev/null; then
    check_pass "PDFFileExtractor: error enum is Sendable"
else
    check_fail "PDFFileExtractor: error enum Sendable missing"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "Round 279 Phase 1A Preflight Summary"
echo "=========================================="

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Checks: $TOTAL total"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All checks passed! ✅${NC}"
    echo "PDF file intake infrastructure ready."
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. See details above.${NC}"
    exit 1
fi
