#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Mac Merge + Build + Repair Round 116"
echo "=========================================="

BRANCH_NAME="claude/round76-release-gate-audit-cloud"
REPORT_DIR="reports"

mkdir -p "$REPORT_DIR"

# Step 1: Fetch and checkout main
echo ""
echo "== Step 1: Fetch origin =="
git fetch origin

echo ""
echo "== Step 2: Checkout main =="
git checkout main

# Step 3: Merge cloud branch
echo ""
echo "== Step 3: Merge cloud branch =="
if git merge "origin/$BRANCH_NAME" --no-ff -m "Merge $BRANCH_NAME to main"; then
  echo "✅ Merge successful"
else
  echo "⚠️  Merge conflict detected"
  echo "Resolve conflicts and run: git add . && git commit --no-edit"
  exit 1
fi

# Step 4: Run pbxproj audit
echo ""
echo "== Step 4: Run pbxproj target audit =="
if python3 scripts/pbxproj_target_audit.py; then
  echo "✅ All required files present"
else
  echo "⚠️  Missing files detected"
  read -p "Auto-register with mac_register_round116_files.rb? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ruby scripts/mac_register_round116_files.rb
  fi
fi

# Step 5: Debug build
echo ""
echo "== Step 5: Debug build =="
if xcodebuild -scheme MyTeam -configuration Debug -derivedDataPath build/Debug 2>&1 | tee "$REPORT_DIR/debug_build.log"; then
  echo "✅ Debug build succeeded"
else
  echo "❌ Debug build failed (see $REPORT_DIR/debug_build.log)"
  exit 1
fi

# Step 6: Release build
echo ""
echo "== Step 6: Release build =="
if xcodebuild -scheme MyTeam -configuration Release -derivedDataPath build/Release 2>&1 | tee "$REPORT_DIR/release_build.log"; then
  echo "✅ Release build succeeded"
else
  echo "❌ Release build failed (see $REPORT_DIR/release_build.log)"
  exit 1
fi

# Step 7: Check ToolExecutor warning
echo ""
echo "== Step 7: ToolExecutor Swift 6 check =="
if grep -n "warning:" "$REPORT_DIR/release_build.log" | grep -i "toolexecutor\|mainactor" || true; then
  echo "⚠️  ToolExecutor warning detected (manual review needed)"
else
  echo "✅ No ToolExecutor warnings"
fi

# Step 8: Verify validators compiled
echo ""
echo "== Step 8: Validator compilation check =="
if grep -n "ToolContractValidator" "$REPORT_DIR/release_build.log" | grep -i "error" || true; then
  echo "❌ ToolContractValidator compilation error"
  exit 1
else
  echo "✅ ToolContractValidator compiled"
fi

echo ""
echo "=========================================="
echo "✅ Mac build verification complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review build logs in $REPORT_DIR/"
echo "2. Commit build reports: git add reports/ && git commit -m 'Add Mac build reports'"
echo "3. Push to origin/main: git push origin main"
