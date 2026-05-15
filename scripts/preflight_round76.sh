#!/usr/bin/env bash
# preflight_round76.sh — Round 76A-95Z Release Gate Preflight
# 실행: bash scripts/preflight_round76.sh
# 전제: Xcode CLI tools 설치됨, 프로젝트 루트에서 실행

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM_DIR="$PROJECT_ROOT/MyTeam"
PASS=0
FAIL=0
WARN=0

ok()   { echo "  ✅ $*"; ((PASS++)) || true; }
fail() { echo "  ❌ $*"; ((FAIL++)) || true; }
warn() { echo "  ⚠️  $*"; ((WARN++)) || true; }

echo ""
echo "══════════════════════════════════════════════════"
echo "  MyTeam Round 76A-95Z Release Gate Preflight"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "══════════════════════════════════════════════════"

# ─────────────────────────────────────────
# 1. Swift 소스 금지 표현 검사 (Privacy Copy)
# ─────────────────────────────────────────
echo ""
echo "▶ [1] Privacy Copy Forbidden Phrases"

FORBIDDEN_PHRASES=("완전 로컬" "외부 서버 없음" "내 기기 안에서만" "어떤 데이터도 외부로 나가지 않음" "서버 없음")
PRIVACY_CLEAN=true

for phrase in "${FORBIDDEN_PHRASES[@]}"; do
    hits=$(grep -rn "$phrase" "$MYTEAM_DIR" --include="*.swift" 2>/dev/null || true)
    if [ -n "$hits" ]; then
        fail "Forbidden phrase found: \"$phrase\""
        echo "$hits" | sed 's/^/      /'
        PRIVACY_CLEAN=false
    fi
done

if $PRIVACY_CLEAN; then
    ok "No forbidden privacy phrases in Swift source"
fi

# ─────────────────────────────────────────
# 2. CharacterAssetPipeline 파일 존재 확인
# ─────────────────────────────────────────
echo ""
echo "▶ [2] Character Asset Pipeline Files"

REQUIRED_FILES=(
    "CharacterAssetManifest.swift"
    "CharacterAssetAvailability.swift"
    "ReleaseVisibleCharacterPolicy.swift"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$MYTEAM_DIR/$f" ]; then
        ok "$f exists"
    else
        fail "$f MISSING"
    fi
done

# ─────────────────────────────────────────
# 3. pbxproj에 새 파일 등록 확인
# ─────────────────────────────────────────
echo ""
echo "▶ [3] pbxproj Registration"

PBXPROJ="$PROJECT_ROOT/MyTeam/MyTeam.xcodeproj/project.pbxproj"
for f in "${REQUIRED_FILES[@]}"; do
    if grep -q "$f" "$PBXPROJ" 2>/dev/null; then
        ok "$f registered in pbxproj"
    else
        fail "$f NOT registered in pbxproj"
    fi
done

# ─────────────────────────────────────────
# 4. Copyright 확인
# ─────────────────────────────────────────
echo ""
echo "▶ [4] Copyright String"

if grep -q "DALGRACSTUDIO" "$PBXPROJ" 2>/dev/null; then
    ok "DALGRACSTUDIO copyright found in pbxproj"
else
    fail "DALGRACSTUDIO copyright NOT found in pbxproj"
fi

# ─────────────────────────────────────────
# 5. Permission Usage Strings
# ─────────────────────────────────────────
echo ""
echo "▶ [5] Permission Copy"

if grep -q "회의록 작성" "$PBXPROJ" 2>/dev/null; then
    ok "Microphone usage copy updated (회의록 작성)"
else
    warn "Microphone usage copy not found — check NSMicrophoneUsageDescription"
fi

if grep -q "날씨·지역" "$PBXPROJ" 2>/dev/null; then
    ok "Location usage copy updated (날씨·지역)"
else
    warn "Location usage copy not found — check NSLocationWhenInUseUsageDescription"
fi

# ─────────────────────────────────────────
# 6. 핵심 문서 존재 확인
# ─────────────────────────────────────────
echo ""
echo "▶ [6] Review Documents"

DOCS=(
    "docs/InternalReviewReport.md"
    "docs/character/ScreenshotReadinessPlan.md"
    "docs/growth/MarketingReviewAcceptanceMatrix.md"
)

for d in "${DOCS[@]}"; do
    if [ -f "$PROJECT_ROOT/$d" ]; then
        ok "$d exists"
    else
        warn "$d not found"
    fi
done

# ─────────────────────────────────────────
# 7. ToolContractValidator / RouterBurnInSuite
# ─────────────────────────────────────────
echo ""
echo "▶ [7] Validation Suite Files"

for f in "ToolContractValidator.swift" "RouterBurnInSuite.swift"; do
    if [ -f "$MYTEAM_DIR/$f" ]; then
        ok "$f exists"
    else
        fail "$f MISSING"
    fi
done

# ─────────────────────────────────────────
# 8. ReleaseWarningAudit 문서
# ─────────────────────────────────────────
echo ""
echo "▶ [8] ReleaseWarningAudit"

if [ -f "$PROJECT_ROOT/docs/ReleaseWarningAudit.md" ]; then
    ok "ReleaseWarningAudit.md exists"
else
    warn "ReleaseWarningAudit.md not found"
fi

# ─────────────────────────────────────────
# 9. DEVLOG.md 최근 업데이트 확인
# ─────────────────────────────────────────
echo ""
echo "▶ [9] DEVLOG Recency"

if grep -q "Round 76\|76A\|2026-05" "$PROJECT_ROOT/DEVLOG.md" 2>/dev/null; then
    ok "DEVLOG.md contains Round 76 or 2026-05 entry"
else
    warn "DEVLOG.md may not have Round 76 entry"
fi

# ─────────────────────────────────────────
# 10. Git 상태 요약
# ─────────────────────────────────────────
echo ""
echo "▶ [10] Git Status"

cd "$PROJECT_ROOT"
MODIFIED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
if [ "$MODIFIED" -eq 0 ]; then
    ok "Git working tree clean"
else
    warn "$MODIFIED file(s) modified/untracked — commit pending"
fi

# ─────────────────────────────────────────
# Summary
# ─────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════"
echo "  PASS=$PASS  WARN=$WARN  FAIL=$FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo "  🚫 $FAIL item(s) FAILED — fix before Release commit"
    echo "══════════════════════════════════════════════════"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "  ⚠️  $WARN warning(s) — review before App Store submission"
    echo "══════════════════════════════════════════════════"
    exit 0
else
    echo "  🎉 All checks passed"
    echo "══════════════════════════════════════════════════"
    exit 0
fi
