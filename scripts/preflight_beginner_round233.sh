#!/usr/bin/env bash
# preflight_beginner_round233.sh
# Round 233B Beginner Mode UX — 사전 빌드 검증 스크립트
# 간편 모드 구성 요소가 모두 존재하고 pbxproj에 등록되어 있는지 확인한다.
# 실패 시 exit 1, 성공 시 exit 0.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MYTEAM="$REPO_ROOT/MyTeam"
PBXPROJ="$MYTEAM/MyTeam.xcodeproj/project.pbxproj"

pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAILED=$((FAILED + 1)); }
FAILED=0

echo ""
echo "══════════════════════════════════════════════"
echo " Round 233B Beginner Mode Preflight"
echo "══════════════════════════════════════════════"
echo ""

# ── 1. 필수 파일 존재 확인 ──────────────────────────────────
echo "[ 1/5 ] 필수 소스 파일 존재 확인"

FILES=(
    "BeginnerMode.swift"
    "BeginnerTaskCardView.swift"
    "BeginnerExampleDocumentService.swift"
    "WorkroomHomeView.swift"
    "ArtifactCardView.swift"
)

for f in "${FILES[@]}"; do
    if [ -f "$MYTEAM/$f" ]; then
        pass "$f 존재"
    else
        fail "$f 없음"
    fi
done

# ── 2. pbxproj 등록 확인 ───────────────────────────────────
echo ""
echo "[ 2/5 ] project.pbxproj 등록 확인"

PBXPROJ_KEYS=(
    "BC233A001FR00001FR001001"   # BeginnerMode.swift FileRef
    "BC233A001BF00001BF001001"   # BeginnerMode.swift BuildFile
    "BC233A002FR00002FR002002"   # BeginnerTaskCardView.swift FileRef
    "BC233A002BF00002BF002002"   # BeginnerTaskCardView.swift BuildFile
    "BC233B001FR00001FR001001"   # BeginnerExampleDocumentService.swift FileRef
    "BC233B001BF00001BF001001"   # BeginnerExampleDocumentService.swift BuildFile
)

for key in "${PBXPROJ_KEYS[@]}"; do
    if grep -q "$key" "$PBXPROJ"; then
        pass "pbxproj: $key"
    else
        fail "pbxproj: $key 미등록"
    fi
done

# ── 3. 핵심 심볼 존재 확인 ────────────────────────────────
echo ""
echo "[ 3/5 ] 핵심 심볼 존재 확인"

check_symbol() {
    local file="$MYTEAM/$1"
    local symbol="$2"
    if grep -q "$symbol" "$file" 2>/dev/null; then
        pass "$1: '$symbol' 확인"
    else
        fail "$1: '$symbol' 없음"
    fi
}

check_symbol "BeginnerMode.swift" "enum BeginnerTaskCard"
check_symbol "BeginnerMode.swift" "struct BeginnerGuidanceMessage"
check_symbol "BeginnerMode.swift" "enum UserFacingTerm"
check_symbol "BeginnerMode.swift" "case tryExample"
check_symbol "BeginnerMode.swift" "static let firstLaunch"
check_symbol "BeginnerMode.swift" "friendlyErrorMessage"

check_symbol "BeginnerExampleDocumentService.swift" "class BeginnerExampleDocumentService"
check_symbol "BeginnerExampleDocumentService.swift" "generateExampleMeetingMinutes"
check_symbol "BeginnerExampleDocumentService.swift" "workflowCompleted"

check_symbol "WorkroomHomeView.swift" "isBeginnerMode"
check_symbol "WorkroomHomeView.swift" "BeginnerTaskCardView"
check_symbol "WorkroomHomeView.swift" "BeginnerGuidanceBar"
check_symbol "WorkroomHomeView.swift" "handleBeginnerCardTap"
check_symbol "WorkroomHomeView.swift" "BeginnerExampleDocumentService"

check_symbol "ArtifactCardView.swift" "friendlyRecovery"
check_symbol "ArtifactCardView.swift" "RecoveryInfo"
check_symbol "ArtifactCardView.swift" "RecoveryAction"

# ── 4. SettingsView 간편 모드 토글 확인 ────────────────────
echo ""
echo "[ 4/5 ] SettingsView 간편 모드 토글 확인"

SETTINGS="$MYTEAM/SettingsView.swift"
if grep -q "isBeginnerMode" "$SETTINGS" 2>/dev/null; then
    pass "SettingsView: isBeginnerMode 토글 확인"
else
    fail "SettingsView: isBeginnerMode 토글 없음"
fi

if grep -q "간편 모드" "$SETTINGS" 2>/dev/null; then
    pass "SettingsView: '간편 모드' 레이블 확인"
else
    fail "SettingsView: '간편 모드' 레이블 없음"
fi

# ── 5. xcodebuild Debug 빌드 확인 ──────────────────────────
echo ""
echo "[ 5/5 ] xcodebuild Debug 빌드 확인"

BUILD_OUTPUT=$(xcodebuild \
    -project "$MYTEAM/MyTeam.xcodeproj" \
    -scheme MyTeam \
    -configuration Debug \
    build 2>&1 | tail -5)

if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    pass "xcodebuild Debug: BUILD SUCCEEDED"
else
    fail "xcodebuild Debug: BUILD FAILED"
    echo "$BUILD_OUTPUT"
fi

# ── 결과 요약 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
    echo "✅ Round 233B Beginner Mode Preflight: 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════"
    exit 0
else
    echo "❌ Round 233B Beginner Mode Preflight: $FAILED 항목 실패"
    echo "══════════════════════════════════════════════"
    exit 1
fi
