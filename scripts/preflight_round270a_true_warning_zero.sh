#!/usr/bin/env bash
# preflight_round270a_true_warning_zero.sh
# Round 270A: True Warning Zero Gate
# xcodebuild를 실제로 실행해 Swift 경고 개수를 측정한다.
# (mlx-swift C++ 경고는 제3자 코드이므로 제외)
# 2개 검사

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== Round 270A TRUE WARNING-ZERO-GATE Preflight ==="
echo

# Debug 빌드 Swift 경고 수집 (mlx-swift C++ 경고 제외)
echo "→ Debug 빌드 중 (clean)..."
WARN_DEBUG=$(xcodebuild \
  -project "$ROOT/MyTeam/MyTeam.xcodeproj" \
  -scheme MyTeam \
  -configuration Debug \
  clean build 2>&1 \
  | { grep ': warning:' || true; } \
  | { grep -v 'mlx\|OnnxRuntimeBindings\|onnxruntime' || true; } \
  | wc -l | tr -d ' ')

echo "  Debug Swift warnings: $WARN_DEBUG"

if [ "$WARN_DEBUG" -eq 0 ]; then
    ok "Debug 빌드 Swift 경고 0개"
else
    fail "Debug 빌드 Swift 경고 ${WARN_DEBUG}개"
fi

# Release 빌드 Swift 경고 수집
echo "→ Release 빌드 중..."
WARN_RELEASE=$(xcodebuild \
  -project "$ROOT/MyTeam/MyTeam.xcodeproj" \
  -scheme MyTeam \
  -configuration Release \
  build 2>&1 \
  | { grep ': warning:' || true; } \
  | { grep -v 'mlx\|OnnxRuntimeBindings\|onnxruntime' || true; } \
  | wc -l | tr -d ' ')

echo "  Release Swift warnings: $WARN_RELEASE"

if [ "$WARN_RELEASE" -eq 0 ]; then
    ok "Release 빌드 Swift 경고 0개"
else
    fail "Release 빌드 Swift 경고 ${WARN_RELEASE}개"
fi

echo
echo "=== 결과: PASS=$PASS FAIL=$FAIL / 2 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
