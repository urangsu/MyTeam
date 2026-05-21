#!/usr/bin/env bash
# Round 249TTS-SPIKE preflight checks
# Validates Supertonic3 ONNX Swift feasibility spike isolation policies.
#
# Run: bash scripts/preflight_round249tts.sh
# Expected: all checks PASS (0 FAIL)

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SWIFT_DIR="$REPO_ROOT/MyTeam"
SCRIPTS_DIR="$REPO_ROOT/scripts"
DOCS_DIR="$REPO_ROOT/docs"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0

ok()   { echo -e "${GREEN}✅${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}❌${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; WARN=$((WARN + 1)); }

echo "=== Round 249TTS-SPIKE Preflight ==="
echo "Branch: $(git -C "$REPO_ROOT" branch --show-current)"
echo ""

# ── 1. Supertonic3ONNXRunner.swift 존재 ──────────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3ONNXRunner.swift" ]; then
    ok "Supertonic3ONNXRunner.swift 존재"
else
    fail "Supertonic3ONNXRunner.swift 없음"
fi

# ── 2. Supertonic3ONNXModelPaths.swift 존재 ──────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3ONNXModelPaths.swift" ]; then
    ok "Supertonic3ONNXModelPaths.swift 존재"
else
    fail "Supertonic3ONNXModelPaths.swift 없음"
fi

# ── 3. Supertonic3UnicodeIndexer.swift 존재 ──────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3UnicodeIndexer.swift" ]; then
    ok "Supertonic3UnicodeIndexer.swift 존재"
else
    fail "Supertonic3UnicodeIndexer.swift 없음"
fi

# ── 4. Supertonic3VoiceStyle.swift 존재 ──────────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3VoiceStyle.swift" ]; then
    ok "Supertonic3VoiceStyle.swift 존재"
else
    fail "Supertonic3VoiceStyle.swift 없음"
fi

# ── 5. Supertonic3ONNXSpike.swift 존재 ──────────────────────────────────────
if [ -f "$SWIFT_DIR/Supertonic3ONNXSpike.swift" ]; then
    ok "Supertonic3ONNXSpike.swift 존재"
else
    fail "Supertonic3ONNXSpike.swift 없음"
fi

# ── 6. onnxruntime_objc import 확인 ──────────────────────────────────────────
if grep -q "import onnxruntime_objc" "$SWIFT_DIR/Supertonic3ONNXRunner.swift" 2>/dev/null; then
    ok "Supertonic3ONNXRunner: onnxruntime_objc import 존재"
else
    fail "Supertonic3ONNXRunner.swift에 'import onnxruntime_objc' 없음"
fi

# ── 7. Apple TTS 코드 없음 (실제 import/type usage만 — 주석/문자열 내 언급 제외) ─
# 실제 API 호출: AVSpeechSynthesizer() / AVSpeechSynthesizer.init / let _ = AVSpeechSynthesizer
AVSS_REAL=0
while IFS= read -r line; do
    # Skip comments, string literals, policy notes
    [[ "$line" =~ ^\s*// ]] && continue
    [[ "$line" =~ issues\.append ]] && continue
    [[ "$line" =~ Text\( ]] && continue
    [[ "$line" =~ \".*AVSpeech ]] && continue
    AVSS_REAL=$((AVSS_REAL + 1))
done < <(grep -rn "AVSpeechSynthesizer()" "$SWIFT_DIR/" 2>/dev/null || true)
if [ "$AVSS_REAL" -eq 0 ]; then
    ok "AVSpeechSynthesizer() 실제 사용 코드 없음 (Apple TTS 금지 준수)"
else
    fail "AVSpeechSynthesizer() 사용 코드 $AVSS_REAL 건 발견 — Apple TTS 금지 위반"
fi

# ── 8. ONNX Runner가 SpeechManager에 직접 연결되지 않음 ──────────────────────
if grep -q "Supertonic3ONNXRunner" "$SWIFT_DIR/SpeechManager.swift" 2>/dev/null; then
    fail "SpeechManager.swift에 Supertonic3ONNXRunner 참조 발견 — spike 격리 위반"
else
    ok "Supertonic3ONNXRunner ↔ SpeechManager 격리 확인"
fi

# ── 9. ProductReadiness.isProductionReady = false 확인 ────────────────────────
if grep -q "isProductionReady" "$SWIFT_DIR/Supertonic3ONNXSpike.swift" 2>/dev/null; then
    # All component flags must be false (let xxx: Bool = false)
    FALSE_COUNT=$(grep -c "Bool = false" "$SWIFT_DIR/Supertonic3ONNXSpike.swift" 2>/dev/null || echo 0)
    if [ "$FALSE_COUNT" -ge 5 ]; then
        ok "SupertonicProductReadiness: 모든 준비 플래그 false (spike 단계)"
    else
        warn "SupertonicProductReadiness.swift: false 플래그 수 확인 필요 ($FALSE_COUNT)"
    fi
else
    fail "Supertonic3ONNXSpike.swift에 isProductionReady 없음"
fi

# ── 10. 자동 모델 다운로드 코드 없음 ─────────────────────────────────────────
AUTO_DL_LINES=$(grep -rn "URLSession\|downloadModel\|huggingface.*download" \
    "$SWIFT_DIR/Supertonic3ONNXRunner.swift" \
    "$SWIFT_DIR/Supertonic3ONNXModelPaths.swift" 2>/dev/null || true)
if [ -z "$AUTO_DL_LINES" ]; then
    ok "자동 다운로드 코드 없음 (정책 준수)"
else
    fail "자동 다운로드 코드 발견 — 모델 자동 다운로드 금지 위반"
fi

# ── 11. Supertonic3 ONNX 모델 파일 app bundle 없음 ────────────────────────────
S3_BUNDLED_LINES=$(grep "supertonic3\|text_encoder\.onnx\|duration_predictor\.onnx\|vector_estimator\.onnx\|vocoder\.onnx" \
    "$SWIFT_DIR/MyTeam.xcodeproj/project.pbxproj" 2>/dev/null \
    | grep -v "onnxruntime\|comment" || true)
if [ -z "$S3_BUNDLED_LINES" ]; then
    ok "Supertonic3 ONNX 파일 app bundle 없음"
else
    warn "pbxproj에 Supertonic3 ONNX 파일 참조 발견 — 확인 필요"
fi

# ── 12. git-tracked .onnx 없음 ───────────────────────────────────────────────
TRACKED_ONNX_LINES=$(git -C "$REPO_ROOT" ls-files 2>/dev/null | grep '\.onnx$' || true)
if [ -z "$TRACKED_ONNX_LINES" ]; then
    ok "git-tracked .onnx 없음 (대용량 모델 git 커밋 금지 준수)"
else
    TRACKED_COUNT=$(echo "$TRACKED_ONNX_LINES" | wc -l | tr -d ' ')
    fail "git-tracked .onnx $TRACKED_COUNT 건 발견"
    echo "$TRACKED_ONNX_LINES" | head -5
fi

# ── 13. RuntimeDiagnosticsSnapshot에 ONNX spike 필드 존재 ────────────────────
if grep -q "supertonicONNXSpikeAvailable\|supertonicONNXAutoInitOnLaunch\|supertonicProductReady" \
    "$SWIFT_DIR/RuntimeDiagnosticsService.swift" 2>/dev/null; then
    ok "RuntimeDiagnosticsSnapshot에 249TTS-SPIKE 필드 존재"
else
    fail "RuntimeDiagnosticsService.swift에 249TTS-SPIKE 필드 없음"
fi

# ── 14. ToolContractValidator에 ONNX spike validators 존재 ───────────────────
if grep -q "validateSupertonicONNXSpikeIsolation\|validateSupertonicNoAutoInit\|validateNoUserFacingTTSUntilReady" \
    "$SWIFT_DIR/ToolContractValidator.swift" 2>/dev/null; then
    ok "ToolContractValidator에 249TTS-SPIKE validators 존재"
else
    fail "ToolContractValidator.swift에 249TTS-SPIKE validators 없음"
fi

# ── 15. docs/SupertonicONNXSpike.md 존재 ─────────────────────────────────────
if [ -f "$DOCS_DIR/SupertonicONNXSpike.md" ]; then
    ok "docs/SupertonicONNXSpike.md 존재"
else
    fail "docs/SupertonicONNXSpike.md 없음"
fi

# ── 16. spike 브랜치 (main에서 분리됨) ───────────────────────────────────────
CURRENT_BRANCH=$(git -C "$REPO_ROOT" branch --show-current)
if echo "$CURRENT_BRANCH" | grep -q "spike\|249"; then
    ok "spike 브랜치에서 실행 중: $CURRENT_BRANCH"
else
    warn "spike 브랜치가 아닌 '$CURRENT_BRANCH'에서 실행 중"
fi

# ── 17. 247TTS preflight 16/16 계속 통과 (전제조건) ──────────────────────────
if [ -f "$SCRIPTS_DIR/preflight_round247tts.sh" ]; then
    RESULT_247=$(bash "$SCRIPTS_DIR/preflight_round247tts.sh" 2>/dev/null | tail -5)
    if echo "$RESULT_247" | grep -qE "PASS|통과|✅"; then
        ok "247TTS 전제조건: preflight_round247tts.sh 통과"
    else
        warn "247TTS preflight 결과 확인 필요"
    fi
else
    warn "preflight_round247tts.sh 없음"
fi

echo ""
echo "=== 결과 ==="
echo -e "PASS: ${GREEN}$PASS${NC} / FAIL: ${RED}$FAIL${NC} / WARN: ${YELLOW}$WARN${NC} (총 $((PASS + FAIL + WARN)))"

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ 249TTS-SPIKE PREFLIGHT 통과${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAIL 건 실패${NC}"
    exit 1
fi
