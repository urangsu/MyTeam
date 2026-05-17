#!/usr/bin/env bash
# preflight_sprite_round234.sh
# Round 234 Preflight — Sprite Asset Gate + Beginner Flow QA 직전 점검
#
# 실패(exit 1): 필수 파일 누락, 금지 문구 검출, 빌드 실패
# 경고(exit 0): 없음 (이 스크립트는 경고를 발행하지 않음)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/MyTeam/MyTeam.xcodeproj"
SCHEME="MyTeam"

FAILED=0

pass()  { echo "✅ $1"; }
fail()  { echo "❌ $1"; FAILED=$((FAILED + 1)); }
info()  { echo "ℹ️  $1"; }

echo ""
echo "══════════════════════════════════════════════════════"
echo " MyTeam Preflight — Round 234 Sprite Asset Gate"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. Git 상태 ───────────────────────────────────────────
echo "[ 1/11 ] Git 상태 확인"
git -C "$REPO_ROOT" status --short || true
pass "git status 출력 완료"

# ── 2. Sprite 폴더 확인 ───────────────────────────────────
echo ""
echo "[ 2/11 ] Sprite 폴더 확인"

INTAKE="$REPO_ROOT/Sprites"
RUNTIME="$REPO_ROOT/MyTeam/Resources/Sprites"

if [ -d "$INTAKE" ]; then
    pass "Sprites/ intake 폴더 존재"
else
    fail "Sprites/ intake 폴더 없음: $INTAKE"
fi

if [ -d "$INTAKE/치코" ]; then
    pass "Sprites/치코/ intake 폴더 존재"
else
    fail "Sprites/치코/ intake 폴더 없음"
fi

if [ -d "$RUNTIME/치코" ]; then
    png_count=$(find "$RUNTIME/치코" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    pass "MyTeam/Resources/Sprites/치코/ 존재 ($png_count PNG)"
else
    fail "MyTeam/Resources/Sprites/치코/ 없음 (런타임 스프라이트 미설치)"
fi

# ── 3. validate_sprites.sh 실행 ───────────────────────────
echo ""
echo "[ 3/11 ] validate_sprites.sh 실행"

VALIDATOR="$REPO_ROOT/scripts/validate_sprites.sh"
if [ ! -f "$VALIDATOR" ]; then
    fail "validate_sprites.sh 없음"
else
    if bash "$VALIDATOR"; then
        pass "validate_sprites.sh 통과"
    else
        fail "validate_sprites.sh 실패 (종료 코드 $?)"
    fi
fi

# ── 4. CharacterSpriteAssetPolicy.swift 확인 ─────────────
echo ""
echo "[ 4/11 ] CharacterSpriteAssetPolicy.swift 확인"

POLICY="$REPO_ROOT/MyTeam/CharacterSpriteAssetPolicy.swift"
if [ -f "$POLICY" ]; then
    pass "CharacterSpriteAssetPolicy.swift 존재"
    # 핵심 API 확인
    if grep -q "func validate(" "$POLICY"; then
        pass "  └─ validate() 함수 존재"
    else
        fail "  └─ validate() 함수 없음"
    fi
    if grep -q "isReadyForRelease" "$POLICY"; then
        pass "  └─ isReadyForRelease 속성 존재"
    else
        fail "  └─ isReadyForRelease 없음"
    fi
else
    fail "CharacterSpriteAssetPolicy.swift 없음"
fi

# ── 5. CharacterSpriteManifest.swift 확인 ────────────────
echo ""
echo "[ 5/11 ] CharacterSpriteManifest.swift 확인"

MANIFEST="$REPO_ROOT/MyTeam/CharacterSpriteManifest.swift"
if [ -f "$MANIFEST" ]; then
    pass "CharacterSpriteManifest.swift 존재"
    if grep -q "requiredStates" "$MANIFEST"; then
        pass "  └─ requiredStates 필드 존재"
    else
        fail "  └─ requiredStates 없음"
    fi
    if grep -q "releaseVisible" "$MANIFEST"; then
        pass "  └─ releaseVisible 필드 존재"
    else
        fail "  └─ releaseVisible 없음"
    fi
else
    fail "CharacterSpriteManifest.swift 없음"
fi

# ── 6. BeginnerExampleDocumentService.swift 확인 ─────────
echo ""
echo "[ 6/11 ] BeginnerExampleDocumentService.swift 확인"

BEGINNER_SVC="$REPO_ROOT/MyTeam/BeginnerExampleDocumentService.swift"
if [ -f "$BEGINNER_SVC" ]; then
    pass "BeginnerExampleDocumentService.swift 존재"
    if grep -q "generateExampleMeetingMinutes" "$BEGINNER_SVC"; then
        pass "  └─ generateExampleMeetingMinutes 함수 존재"
    else
        fail "  └─ generateExampleMeetingMinutes 없음"
    fi
    if grep -q "registerArtifact" "$BEGINNER_SVC"; then
        pass "  └─ registerArtifact 호출 존재"
    else
        fail "  └─ registerArtifact 호출 없음"
    fi
else
    fail "BeginnerExampleDocumentService.swift 없음"
fi

# ── 7. CharacterReactionEngine.swift 확인 ────────────────
echo ""
echo "[ 7/11 ] CharacterReactionEngine.swift 확인"

REACTION_ENGINE="$REPO_ROOT/MyTeam/CharacterReactionEngine.swift"
if [ -f "$REACTION_ENGINE" ]; then
    pass "CharacterReactionEngine.swift 존재"
else
    fail "CharacterReactionEngine.swift 없음"
fi

# ── 8. 금지 개인정보/기술 문구 검색 ─────────────────────
echo ""
echo "[ 8/11 ] 금지 개인정보 문구 검색 (Swift 소스)"

SWIFT_DIR="$REPO_ROOT/MyTeam"
PRIVACY_PATTERNS=(
    "UserDefaults.*token"
    "UserDefaults.*apiKey"
    "UserDefaults.*api_key"
    "UserDefaults.*password"
    "print.*token"
    "print.*apiKey"
    "AppLog.*token"
)

privacy_fail=0
for pattern in "${PRIVACY_PATTERNS[@]}"; do
    hits=$(grep -r -l --include="*.swift" -E "$pattern" "$SWIFT_DIR" 2>/dev/null || true)
    if [ -n "$hits" ]; then
        fail "금지 패턴 발견 '$pattern': $hits"
        privacy_fail=$((privacy_fail + 1))
    fi
done

if [ "$privacy_fail" -eq 0 ]; then
    pass "개인정보 금지 문구 없음"
fi

# ── 9. 금지 기술 UX 문구 검색 ────────────────────────────
echo ""
echo "[ 9/11 ] 금지 기술 UX 문구 검색 (Swift 소스 UI 레이어)"

TECH_PATTERNS=(
    '"해시 불일치"'
    '"hash mismatch"'
    '"경로 오류"'
    '"IMAP 기반"'
    '"read-only 검토"'
    '"rate limit"'
    '"쿨다운"'
    '"스케줄 관리 준비 중"'
)

ui_files=(
    "$REPO_ROOT/MyTeam/ArtifactCardView.swift"
    "$REPO_ROOT/MyTeam/DailyBriefingCardView.swift"
    "$REPO_ROOT/MyTeam/TeamStatusView.swift"
    "$REPO_ROOT/MyTeam/SettingsView.swift"
    "$REPO_ROOT/MyTeam/AssistantConnectorCatalog.swift"
)

tech_fail=0
for pattern in "${TECH_PATTERNS[@]}"; do
    for file in "${ui_files[@]}"; do
        [ -f "$file" ] || continue
        if grep -qF "$pattern" "$file" 2>/dev/null; then
            fail "기술 UX 문구 발견 '$pattern' in $(basename $file)"
            tech_fail=$((tech_fail + 1))
        fi
    done
done

if [ "$tech_fail" -eq 0 ]; then
    pass "기술 UX 금지 문구 없음"
fi

# ── 10. Debug 빌드 ────────────────────────────────────────
echo ""
echo "[ 10/11 ] Debug 빌드"

if xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"; then
    pass "Debug BUILD SUCCEEDED"
else
    fail "Debug BUILD FAILED"
fi

# ── 11. Release 빌드 ──────────────────────────────────────
echo ""
echo "[ 11/11 ] Release 빌드"

if xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"; then
    pass "Release BUILD SUCCEEDED"
else
    fail "Release BUILD FAILED"
fi

# ── 결과 요약 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
    echo "✅ Preflight Round 234 전체 통과 (0 실패)"
    echo "══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Preflight Round 234 실패: $FAILED 오류"
    echo "══════════════════════════════════════════════════════"
    exit 1
fi
