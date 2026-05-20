#!/usr/bin/env bash
# preflight_observation_round243a.sh
# Round 243A-OBSERVE: Local Observation Foundation 검증
# Cloud 환경 — xcodebuild 실행하지 않음

set -euo pipefail
PASS=0; FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MT="$ROOT/MyTeam"

ok()   { echo "  ✅  $1"; ((PASS++)) || true; }
fail() { echo "  ❌  $1"; ((FAIL++)) || true; }

echo ""
echo "══════════════════════════════════════════"
echo "  Round 243A-OBSERVE Preflight"
echo "══════════════════════════════════════════"
echo ""

# 1. ObservationModels.swift 존재
[ -f "$MT/ObservationModels.swift" ] \
  && ok "ObservationModels.swift 존재" \
  || fail "ObservationModels.swift 없음"

# 2. LocalObservationService.swift 존재
[ -f "$MT/LocalObservationService.swift" ] \
  && ok "LocalObservationService.swift 존재" \
  || fail "LocalObservationService.swift 없음"

# 3. DownloadsFolderWatcher.swift 존재
[ -f "$MT/DownloadsFolderWatcher.swift" ] \
  && ok "DownloadsFolderWatcher.swift 존재" \
  || fail "DownloadsFolderWatcher.swift 없음"

# 4. ClipboardContextReader.swift 존재
[ -f "$MT/ClipboardContextReader.swift" ] \
  && ok "ClipboardContextReader.swift 존재" \
  || fail "ClipboardContextReader.swift 없음"

# 5. FinderSelectionReader.swift 존재
[ -f "$MT/FinderSelectionReader.swift" ] \
  && ok "FinderSelectionReader.swift 존재" \
  || fail "FinderSelectionReader.swift 없음"

# 6. ScreenObservationPolicy.swift 존재
[ -f "$MT/ScreenObservationPolicy.swift" ] \
  && ok "ScreenObservationPolicy.swift 존재" \
  || fail "ScreenObservationPolicy.swift 없음"

# 7. Downloads watcher default OFF 패턴
grep -q "defaultEnabled = false\|isEnabled: Bool = false" "$MT/DownloadsFolderWatcher.swift" \
  && ok "DownloadsFolderWatcher default OFF 확인" \
  || fail "DownloadsFolderWatcher default OFF 패턴 없음"

# 8. Clipboard explicit only 정책
grep -q "continuousMonitoringAllowed = false" "$MT/ClipboardContextReader.swift" \
  && ok "ClipboardContextReader explicit-only 정책 확인" \
  || fail "ClipboardContextReader continuous monitoring block 없음"

# 9. Continuous screen capture blocked
grep -q "continuousCaptureAllowed = false" "$MT/ScreenObservationPolicy.swift" \
  && ok "ScreenObservationPolicy continuous capture blocked 확인" \
  || fail "ScreenObservationPolicy continuousCaptureAllowed = false 없음"

# 10. OfficeReviewInputPolicy 존재
[ -f "$MT/OfficeReviewInputPolicy.swift" ] \
  && ok "OfficeReviewInputPolicy.swift 존재" \
  || fail "OfficeReviewInputPolicy.swift 없음"

# 11. RuntimeDiagnostics observation fields
grep -q "localObservationServiceAvailable\|downloadsWatcherDefaultOff\|screenContinuousCaptureBlocked" "$MT/RuntimeDiagnosticsService.swift" \
  && ok "RuntimeDiagnosticsService observation fields 확인" \
  || fail "RuntimeDiagnosticsService observation fields 없음"

# 12. ToolContractValidator observation validators
grep -q "validateObservationRoomScopePolicy\|validateDownloadsWatcherSafetyPolicy\|validateAutomaticExternalUploadBlockedPolicy" "$MT/ToolContractValidator.swift" \
  && ok "ToolContractValidator observation validators 확인" \
  || fail "ToolContractValidator observation validators 없음"

# 13. pbxproj 등록 여부 (Mac build 필요)
if grep -q "ObservationModels\|LocalObservationService" "$MT/MyTeam.xcodeproj/project.pbxproj" 2>/dev/null; then
  ok "pbxproj에 observation 파일 등록됨"
else
  fail "pbxproj에 observation 파일 미등록 — Mac build 후 scripts/mac_register_round243a_files.rb 실행 필요"
fi

# 14. git diff --check (whitespace error 없음)
cd "$ROOT"
git diff --check HEAD 2>/dev/null \
  && ok "git diff --check 통과 (whitespace 오류 없음)" \
  || fail "git diff --check 실패"

echo ""
echo "══════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅  PASSED  $PASS/$((PASS+FAIL))"
else
  echo "  ❌  FAILED  PASS=$PASS FAIL=$FAIL"
fi
echo "══════════════════════════════════════════"
echo ""
echo "  ⚠️  Cloud 환경 — xcodebuild 실행 안 함"
echo "  Mac build: scripts/mac_register_round243a_files.rb 실행 후 xcodebuild"
echo ""

[ "$FAIL" -eq 0 ]
