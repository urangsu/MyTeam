#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

# Helper function to write to report files
log_report() {
    local file=$1
    local message=$2
    echo "$message" >> "$file"
}

# Initialize main report
MAIN_REPORT="$REPORT_DIR/cloud_preflight_round116.md"
> "$MAIN_REPORT"

echo "# Cloud Preflight Round 116 Report" > "$MAIN_REPORT"
echo "" >> "$MAIN_REPORT"
echo "**Generated:** $(date)" >> "$MAIN_REPORT"
echo "" >> "$MAIN_REPORT"

# Git status
echo "## Git Status" >> "$MAIN_REPORT"
echo '```' >> "$MAIN_REPORT"
git status --short >> "$MAIN_REPORT"
echo '```' >> "$MAIN_REPORT"
echo "**Branch:** $(git branch --show-current)" >> "$MAIN_REPORT"
echo "" >> "$MAIN_REPORT"

# Forbidden privacy copy audit
PRIVACY_REPORT="$REPORT_DIR/forbidden_copy_audit.md"
> "$PRIVACY_REPORT"
echo "# Forbidden Privacy Copy Audit" >> "$PRIVACY_REPORT"
echo "" >> "$PRIVACY_REPORT"
echo "## Forbidden Phrases Check" >> "$PRIVACY_REPORT"
echo "" >> "$PRIVACY_REPORT"

if grep -R "외부 서버 없음\|완전 로컬\|내 기기 안에서만\|어떤 데이터도 외부로 나가지\|서버 없음" --include="*.swift" -n MyTeam 2>/dev/null \
  | grep -v "TruthfulPrivacyCopyPolicy" \
  | grep -v "MarketingReviewAcceptanceMatrix" > /tmp/forbidden_phrases.txt 2>&1 || true; then
  if [ -s /tmp/forbidden_phrases.txt ]; then
    echo "⚠️ **FOUND**: Forbidden phrases detected" >> "$PRIVACY_REPORT"
    echo '```' >> "$PRIVACY_REPORT"
    cat /tmp/forbidden_phrases.txt >> "$PRIVACY_REPORT"
    echo '```' >> "$PRIVACY_REPORT"
    log_report "$MAIN_REPORT" "- ⚠️  Privacy copy audit: forbidden phrases found (see forbidden_copy_audit.md)"
  else
    echo "✅ **PASS**: No forbidden phrases detected" >> "$PRIVACY_REPORT"
    log_report "$MAIN_REPORT" "- ✅ Privacy copy audit: no forbidden phrases"
  fi
else
  echo "✅ **PASS**: No forbidden phrases detected" >> "$PRIVACY_REPORT"
  log_report "$MAIN_REPORT" "- ✅ Privacy copy audit: no forbidden phrases"
fi

# Connector policy audit
CONNECTOR_REPORT="$REPORT_DIR/connector_policy_audit.md"
> "$CONNECTOR_REPORT"
echo "# Connector Policy Audit" >> "$CONNECTOR_REPORT"
echo "" >> "$CONNECTOR_REPORT"

if grep -R "calendarWrite\|mailSend\|externalUpload\|deleteFile" -n MyTeam --include="*.swift" 2>/dev/null > /tmp/connector_writes.txt 2>&1 || true; then
  if [ -s /tmp/connector_writes.txt ]; then
    echo "⚠️ **FOUND**: External write tools detected" >> "$CONNECTOR_REPORT"
    echo '```' >> "$CONNECTOR_REPORT"
    cat /tmp/connector_writes.txt >> "$CONNECTOR_REPORT"
    echo '```' >> "$CONNECTOR_REPORT"
    log_report "$MAIN_REPORT" "- ⚠️  Connector policy: external write tools found (verify blocked)"
  else
    echo "✅ **PASS**: No external write tools exposed" >> "$CONNECTOR_REPORT"
    log_report "$MAIN_REPORT" "- ✅ Connector policy: no exposed write tools"
  fi
else
  echo "✅ **PASS**: No external write tools exposed" >> "$CONNECTOR_REPORT"
  log_report "$MAIN_REPORT" "- ✅ Connector policy: no exposed write tools"
fi

# StoreKit surface audit
STOREKIT_REPORT="$REPORT_DIR/storekit_surface_audit.md"
> "$STOREKIT_REPORT"
echo "# StoreKit Surface Audit" >> "$STOREKIT_REPORT"
echo "" >> "$STOREKIT_REPORT"

if grep -R "makePurchase\|requestReview\|disabled.*Pro\|DLC.*purchase" -n MyTeam --include="*.swift" 2>/dev/null > /tmp/storekit.txt 2>&1 || true; then
  if [ -s /tmp/storekit.txt ]; then
    echo "⚠️ **FOUND**: StoreKit surface detected" >> "$STOREKIT_REPORT"
    echo '```' >> "$STOREKIT_REPORT"
    cat /tmp/storekit.txt >> "$STOREKIT_REPORT"
    echo '```' >> "$STOREKIT_REPORT"
    log_report "$MAIN_REPORT" "- ⚠️  StoreKit surface: found (verify disabled in Release)"
  else
    echo "✅ **PASS**: No obvious StoreKit issues" >> "$STOREKIT_REPORT"
    log_report "$MAIN_REPORT" "- ✅ StoreKit surface: no issues detected"
  fi
else
  echo "✅ **PASS**: No obvious StoreKit issues" >> "$STOREKIT_REPORT"
  log_report "$MAIN_REPORT" "- ✅ StoreKit surface: no issues detected"
fi

# Character surface audit
CHARACTER_REPORT="$REPORT_DIR/character_surface_audit.md"
> "$CHARACTER_REPORT"
echo "# Character Surface Audit" >> "$CHARACTER_REPORT"
echo "" >> "$CHARACTER_REPORT"

CHAR_FILES=("CharacterAssetManifest" "ReleaseVisibleCharacterPolicy" "ProductSurfacePolicy" "CharacterCatalog")
for file in "${CHAR_FILES[@]}"; do
  if grep -q "${file}.swift" MyTeam/MyTeam.xcodeproj/project.pbxproj 2>/dev/null; then
    echo "✅ ${file}.swift" >> "$CHARACTER_REPORT"
  else
    echo "⚠️  ${file}.swift NOT in project" >> "$CHARACTER_REPORT"
  fi
done

log_report "$MAIN_REPORT" "- Character surface: audit complete (see character_surface_audit.md)"
echo "" >> "$MAIN_REPORT"

# Character ID normalization check
if grep -q "CharacterIDNormalizer\|canonicalID" MyTeam/CharacterCatalog.swift 2>/dev/null; then
  log_report "$MAIN_REPORT" "- ✅ Character ID normalization: implemented"
else
  log_report "$MAIN_REPORT" "- ⚠️  Character ID normalization: not found"
fi

# Starter action ID alignment check
if grep -q "starter_meeting_minutes" MyTeam/StarterActionPolicy.swift 2>/dev/null; then
  if grep -q "회의록_양식\|앱_출시_체크리스트" MyTeam/StarterActionPolicy.swift 2>/dev/null; then
    log_report "$MAIN_REPORT" "- ⚠️  Starter action IDs: Korean IDs found (should be starter_*)"
  else
    log_report "$MAIN_REPORT" "- ✅ Starter action IDs: aligned with actual action IDs"
  fi
else
  log_report "$MAIN_REPORT" "- ⚠️  Starter action IDs: 'starter_meeting_minutes' not found"
fi

# pbxproj target audit
PBXPROJ_REPORT="$REPORT_DIR/pbxproj_target_audit.md"
if python3 scripts/pbxproj_target_audit.py 2>/dev/null; then
  log_report "$MAIN_REPORT" "- ✅ pbxproj target audit: passed"
else
  log_report "$MAIN_REPORT" "- ⚠️  pbxproj target audit: review required (see pbxproj_target_audit.md)"
fi

# Final summary
echo "" >> "$MAIN_REPORT"
echo "## Summary" >> "$MAIN_REPORT"
echo "" >> "$MAIN_REPORT"
echo "All reports generated in \`$REPORT_DIR/\`:" >> "$MAIN_REPORT"
echo "- cloud_preflight_round116.md (this file)" >> "$MAIN_REPORT"
echo "- forbidden_copy_audit.md" >> "$MAIN_REPORT"
echo "- connector_policy_audit.md" >> "$MAIN_REPORT"
echo "- storekit_surface_audit.md" >> "$MAIN_REPORT"
echo "- character_surface_audit.md" >> "$MAIN_REPORT"
echo "- pbxproj_target_audit.md" >> "$MAIN_REPORT"
echo "" >> "$MAIN_REPORT"
echo "**Next**: Run \`scripts/mac_merge_build_round116.sh\` on Mac" >> "$MAIN_REPORT"

echo "✅ Cloud preflight complete. Reports generated in $REPORT_DIR/"
