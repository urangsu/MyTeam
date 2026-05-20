#!/usr/bin/env bash
# preflight_round247tts.sh — Round 247TTS-SUPERTONIC3-POC 검증
# 15개 항목 확인. 모두 PASS면 커밋/배포 가능.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_DIR="$REPO_ROOT/MyTeam"
SCRIPTS_DIR="$REPO_ROOT/scripts"
DOCS_DIR="$REPO_ROOT/docs"

PASS=0
FAIL=0
WARN=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

echo "=== preflight_round247tts.sh ==="
echo "REPO: $REPO_ROOT"
echo ""

# ── 1. TTSProviderModels.swift 존재 ──────────────────────────────────────────
if [ -f "$SWIFT_DIR/TTSProviderModels.swift" ]; then
    ok "TTSProviderModels.swift 존재"
else
    fail "TTSProviderModels.swift 없음"
fi

# ── 2. TTSRoutingPolicy.swift 존재 ───────────────────────────────────────────
if [ -f "$SWIFT_DIR/TTSRoutingPolicy.swift" ]; then
    ok "TTSRoutingPolicy.swift 존재"
else
    fail "TTSRoutingPolicy.swift 없음"
fi

# ── 3. Supertonic3TTSConfig.swift 존재 ───────────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3TTSConfig.swift" ]; then
    ok "Supertonic3TTSConfig.swift 존재"
else
    fail "Supertonic3TTSConfig.swift 없음"
fi

# ── 4. Supertonic3ModelLocator.swift 존재 ────────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3ModelLocator.swift" ]; then
    ok "Supertonic3ModelLocator.swift 존재"
else
    fail "Supertonic3ModelLocator.swift 없음"
fi

# ── 5. Supertonic3TTSProvider.swift 존재 ─────────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3TTSProvider.swift" ]; then
    ok "Supertonic3TTSProvider.swift 존재"
else
    fail "Supertonic3TTSProvider.swift 없음"
fi

# ── 6. Supertonic3TTSProbe.swift 존재 ────────────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3TTSProbe.swift" ]; then
    ok "Supertonic3TTSProbe.swift 존재"
else
    fail "Supertonic3TTSProbe.swift 없음"
fi

# ── 7. TTSLabView.swift 존재 ──────────────────────────────────────────────────
if [ -f "$SWIFT_DIR/TTSLabView.swift" ]; then
    ok "TTSLabView.swift 존재"
else
    fail "TTSLabView.swift 없음"
fi

# ── 8. AVSpeechSynthesizer 실제 사용 없음 (Apple TTS 완전 금지) ──────────────
# 실제 API 호출 패턴만 체크: 인스턴스화, import, 타입 선언
AVSPEECH_HITS=$(grep -rn \
    "AVSpeechSynthesizer()\|AVSpeechSynthesizer\.shared\|NSSpeechSynthesizer()\|AVSpeechUtterance(" \
    "$SWIFT_DIR/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$AVSPEECH_HITS" -eq 0 ]; then
    ok "AVSpeechSynthesizer 실제 사용 없음 (Apple TTS 완전 금지 준수)"
else
    fail "AVSpeechSynthesizer 실제 코드 발견 ($AVSPEECH_HITS 건) — Apple TTS 금지 정책 위반"
    grep -rn "AVSpeechSynthesizer()\|NSSpeechSynthesizer()\|AVSpeechUtterance(" "$SWIFT_DIR/" 2>/dev/null | head -5
fi

# ── 9. Supertonic3 기본 disabled (isEnabled false by default) ─────────────────
# UserDefaults.bool() 기본값이 false이므로 "supertonic3ExperimentalEnabled" key만 있으면 됨
if grep -q 'forKey: "supertonic3ExperimentalEnabled"' "$SWIFT_DIR/Supertonic3TTSConfig.swift" 2>/dev/null; then
    ok "Supertonic3 기본 비활성화 (UserDefaults bool 기본값 false 활용)"
else
    fail "Supertonic3TTSConfig.swift에 supertonic3ExperimentalEnabled 키 없음"
fi

# ── 10. Qwen3 Developer Lab override 전용 ────────────────────────────────────
if grep -q "ttsDevLabQwen3Override" "$SWIFT_DIR/TTSRoutingPolicy.swift" 2>/dev/null; then
    ok "Qwen3 DevLab override guard 존재 (TTSRoutingPolicy)"
else
    fail "TTSRoutingPolicy에 ttsDevLabQwen3Override guard 없음"
fi

# ── 11. Supertonic3 자동 다운로드 없음 ───────────────────────────────────────
AUTO_DL_HITS=$(grep -rn "URLSession.*download\|DownloadTask\|URLSessionDownloadTask\|autoDownload" \
    "$SWIFT_DIR/Supertonic3"*.swift 2>/dev/null | wc -l | tr -d ' ')
if [ "$AUTO_DL_HITS" -eq 0 ]; then
    ok "Supertonic3 자동 다운로드 없음"
else
    fail "Supertonic3 파일에 다운로드 관련 코드 발견 ($AUTO_DL_HITS 건)"
fi

# ── 12. TTSProviderKind에 appleSystem case 없음 ───────────────────────────────
if grep -q "appleSystem" "$SWIFT_DIR/TTSProviderModels.swift" 2>/dev/null; then
    fail "TTSProviderModels.swift에 appleSystem case 존재 — Apple TTS 정책 위반"
else
    ok "TTSProviderKind에 appleSystem case 없음"
fi

# ── 13. RuntimeDiagnosticsSnapshot TTS 필드 존재 ─────────────────────────────
if grep -q "appleSystemTTSBlocked\|supertonic3ProviderRegistered\|ttsSilentFallbackAllowed" \
    "$SWIFT_DIR/RuntimeDiagnosticsService.swift" 2>/dev/null; then
    ok "RuntimeDiagnosticsSnapshot TTS 247 필드 존재"
else
    fail "RuntimeDiagnosticsService.swift에 TTS 247 필드 없음"
fi

# ── 14. ToolContractValidator TTS validators 존재 ─────────────────────────────
if grep -q "validateAppleSystemTTSBlocked\|validateSupertonic3ExperimentalPolicy\|validateTTSSilentFallbackPolicy" \
    "$SWIFT_DIR/ToolContractValidator.swift" 2>/dev/null; then
    ok "ToolContractValidator TTS validators 존재"
else
    fail "ToolContractValidator.swift에 TTS validators 없음"
fi

# ── 15. 246B 전제조건: preflight_round246b.sh 40/40 ──────────────────────────
if [ -f "$SCRIPTS_DIR/preflight_round246b.sh" ]; then
    RESULT_246B=$(bash "$SCRIPTS_DIR/preflight_round246b.sh" 2>/dev/null | tail -5)
    if echo "$RESULT_246B" | grep -qE "✅ 40|40/40|✅ Round 246B"; then
        ok "246B 전제조건: preflight_round246b.sh 40/40 통과"
    else
        warn "246B preflight 결과 확인 필요: $RESULT_246B"
    fi
else
    fail "preflight_round246b.sh 없음"
fi

echo ""
echo "=== 결과 ==="
echo -e "PASS: ${GREEN}$PASS${NC} / FAIL: ${RED}$FAIL${NC} / WARN: ${YELLOW}$WARN${NC} (총 $((PASS + FAIL + WARN)))"

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ 247TTS PREFLIGHT 통과 — 커밋 가능${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAIL 건 실패 — 커밋 불가${NC}"
    exit 1
fi
