#!/bin/bash

# Round 245A-P0: Artifact Contract Hotfix Preflight
# Validates WriteTextFileTool artifactPath fix and ToolContractValidator enforcement

set -e

REPORT_FILE="reports/artifact_contract_round245a_preflight.md"
ERRORS=0
WARNINGS=0

echo "# Round 245A-P0: Artifact Contract Hotfix Preflight" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## Checks" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check 1: WriteTextFileTool.swift exists
echo "### 1. WriteTextFileTool.swift existence" >> "$REPORT_FILE"
if [ -f "MyTeam/WriteTextFileTool.swift" ]; then
    echo "✅ WriteTextFileTool.swift found" >> "$REPORT_FILE"
else
    echo "❌ WriteTextFileTool.swift NOT FOUND" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 2: artifactPath uses savedFilename (fixed)
echo "### 2. WriteTextFileTool artifactPath fix verification" >> "$REPORT_FILE"
if grep -q "let savedFilename = url.lastPathComponent" MyTeam/WriteTextFileTool.swift; then
    echo "✅ savedFilename = url.lastPathComponent found" >> "$REPORT_FILE"
else
    echo "⚠️  savedFilename pattern not found (may still be using input filename)" >> "$REPORT_FILE"
    ((WARNINGS++))
fi

if grep -q "artifactPath: filename" MyTeam/WriteTextFileTool.swift; then
    echo "❌ Old pattern 'artifactPath: filename' still present" >> "$REPORT_FILE"
    ((ERRORS++))
else
    echo "✅ Old 'artifactPath: filename' pattern removed" >> "$REPORT_FILE"
fi

if grep -q "artifactPath: savedFilename" MyTeam/WriteTextFileTool.swift; then
    echo "✅ artifactPath uses savedFilename" >> "$REPORT_FILE"
else
    echo "⚠️  Cannot confirm artifactPath: savedFilename pattern" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
echo "" >> "$REPORT_FILE"

# Check 3: summary uses savedFilename
echo "### 3. WriteTextFileTool summary uses actual saved filename" >> "$REPORT_FILE"
if grep -q "let summary = \"\\\\(savedFilename)" MyTeam/WriteTextFileTool.swift; then
    echo "✅ summary correctly uses savedFilename" >> "$REPORT_FILE"
else
    echo "⚠️  Cannot confirm summary uses savedFilename" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
echo "" >> "$REPORT_FILE"

# Check 4: ToolContractValidator has validateWriteTextFileArtifactPathPolicy
echo "### 4. ToolContractValidator enforcement" >> "$REPORT_FILE"
if grep -q "validateWriteTextFileArtifactPathPolicy" MyTeam/ToolContractValidator.swift; then
    echo "✅ validateWriteTextFileArtifactPathPolicy present" >> "$REPORT_FILE"
else
    echo "❌ validateWriteTextFileArtifactPathPolicy NOT found" >> "$REPORT_FILE"
    ((ERRORS++))
fi

if grep -q "validateWriteTextFileArtifactPathPolicy(issues: &issues)" MyTeam/ToolContractValidator.swift; then
    echo "✅ validateWriteTextFileArtifactPathPolicy called in validate()" >> "$REPORT_FILE"
else
    echo "⚠️  validateWriteTextFileArtifactPathPolicy may not be called" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
echo "" >> "$REPORT_FILE"

# Check 5: No debug/release build logs staged
echo "### 5. Build log exclusion" >> "$REPORT_FILE"
if ! git status --short | grep -E "debug-build.log|release-build.log" > /dev/null 2>&1; then
    echo "✅ No debug/release build logs staged" >> "$REPORT_FILE"
else
    echo "❌ Build logs detected in git staging area" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Summary
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Metric | Value |" >> "$REPORT_FILE"
echo "|--------|-------|" >> "$REPORT_FILE"
echo "| Errors | $ERRORS |" >> "$REPORT_FILE"
echo "| Warnings | $WARNINGS |" >> "$REPORT_FILE"
echo "| Status | $([ $ERRORS -eq 0 ] && echo "PASS" || echo "FAIL") |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "## Details" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**P0 Fix:** WriteTextFileTool must return actual saved filename in artifactPath, not input filename." >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Pattern (before):** \`artifactPath: filename\`" >> "$REPORT_FILE"
echo "**Pattern (after):** \`artifactPath: savedFilename\` where \`savedFilename = url.lastPathComponent\`" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "This ensures downstream consumers (RecentArtifactResolver, ArtifactCardView, etc.) reference the correct file even when filename collision triggers \`safeWritableWorkspaceURL\` rename." >> "$REPORT_FILE"

cat "$REPORT_FILE"

if [ $ERRORS -eq 0 ]; then
    echo ""
    echo "✅ Round 245A-P0 artifact contract preflight: PASS"
    exit 0
else
    echo ""
    echo "❌ Round 245A-P0 artifact contract preflight: FAIL ($ERRORS errors)"
    exit 1
fi
