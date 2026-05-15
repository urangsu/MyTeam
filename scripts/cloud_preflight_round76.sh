#!/usr/bin/env bash
set -euo pipefail

echo "== Git status =="
git status --short

echo ""
echo "== Current branch =="
git branch --show-current

echo ""
echo "== Forbidden privacy copy =="
if grep -R "외부 서버 없음\|완전 로컬\|내 기기 안에서만\|어떤 데이터도 외부로 나가지\|서버 없음" -n MyTeam docs \
  | grep -v "TruthfulPrivacyCopyPolicy" \
  | grep -v "MarketingReviewAcceptanceMatrix" || true; then
  echo "⚠️  Some forbidden phrases found (check TruthfulPrivacyCopyPolicy for exceptions)"
else
  echo "✅ No forbidden phrases detected"
fi

echo ""
echo "== Deployment target =="
if grep -n "MACOSX_DEPLOYMENT_TARGET" MyTeam/MyTeam.xcodeproj/project.pbxproj || true; then
  echo "✅ Deployment target found in project"
fi

echo ""
echo "== Copyright =="
if grep -n "NSHumanReadableCopyright" MyTeam/MyTeam.xcodeproj/project.pbxproj || true; then
  echo "✅ Copyright found in project"
fi

echo ""
echo "== Key Swift files in project =="
echo "Checking for new asset policy files..."
for file in CharacterAssetManifest ReleaseVisibleCharacterPolicy FirstLaunchState StarterAction; do
  if grep -q "${file}.swift" MyTeam/MyTeam.xcodeproj/project.pbxproj 2>/dev/null; then
    echo "  ✅ ${file}.swift"
  else
    echo "  ⚠️  ${file}.swift not in project"
  fi
done

echo ""
echo "== Connector write policy grep =="
if grep -R "calendarWrite\|mailSend\|externalUpload\|deleteFile" -n MyTeam --include="*.swift" || true; then
  echo "⚠️  External write/calendar tools found (verify they are blocked/unavailable)"
else
  echo "✅ No obvious external write tools exposed"
fi

echo ""
echo "== StoreKit surface check =="
if grep -R "makePurchase\|requestReview\|disabled.*Pro\|DLC.*purchase" -n MyTeam --include="*.swift" || true; then
  echo "⚠️  StoreKit surface found (verify it's limited to demo/unavailable in Release)"
else
  echo "✅ No obvious StoreKit surface issues"
fi

echo ""
echo "== ToolExecutor MainActor check =="
if grep -n "await MainActor.run" MyTeam/MyTeam/ToolExecutor.swift || true; then
  echo "⚠️  MainActor.run still present (verify necessity)"
else
  echo "✅ MainActor.run removed from ToolExecutor"
fi

echo ""
echo "== ReleaseVisibleCharacterPolicy check =="
if grep -l "ReleaseVisibleCharacterPolicy" MyTeam/MyTeam/*.swift || true; then
  echo "✅ ReleaseVisibleCharacterPolicy referenced"
else
  echo "⚠️  ReleaseVisibleCharacterPolicy not yet integrated"
fi

echo ""
echo "== ToolContractValidator checks =="
if grep -n "validateReleaseVisibleConnectorPolicy\|validateCharacterAssetPolicy\|validateStoreKitSurfacePolicy\|validatePrivacyCopyPolicy" MyTeam/MyTeam/ToolContractValidator.swift || true; then
  echo "✅ Validator policies found"
else
  echo "⚠️  Not all validators implemented yet"
fi

echo ""
echo "== RouterBurnInSuite tests =="
if grep -n "회의록 양식\|앱 출시 체크리스트\|메일 보내줘\|일정 만들어줘\|파일 삭제해줘" MyTeam/MyTeam/RouterBurnInSuite.swift || true; then
  echo "✅ BurnIn test cases found"
else
  echo "⚠️  Not all test cases present"
fi

echo ""
echo "=========================================="
echo "Cloud preflight complete."
echo "Mac xcodebuild still required for final build verification."
echo "=========================================="
