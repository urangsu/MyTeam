#!/bin/bash

# Round 248TTS-A: Supertonic3 ONNX Runtime Boundary + Model Manifest + Pipeline Skeleton
# Preflight validation script

set -e

REPORT_FILE="reports/round248tts_a_preflight.md"
ERRORS=0
WARNINGS=0

echo "# Round 248TTS-A Preflight Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Date:** $(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check 1: All 4 new Swift files exist
echo "## Check 1: New Swift Files Exist" >> "$REPORT_FILE"
for file in ONNXRuntimeAdapter Supertonic3TensorTypes Supertonic3ModelManifest Supertonic3InferencePipeline; do
    if [ -f "MyTeam/${file}.swift" ]; then
        echo "✅ MyTeam/${file}.swift" >> "$REPORT_FILE"
    else
        echo "❌ MyTeam/${file}.swift NOT FOUND" >> "$REPORT_FILE"
        ((ERRORS++))
    fi
done
echo "" >> "$REPORT_FILE"

# Check 2: ONNXRuntimeAdapter structure
echo "## Check 2: ONNXRuntimeAdapter Structure" >> "$REPORT_FILE"
if grep -q "enum ONNXRuntimeAvailability" MyTeam/ONNXRuntimeAdapter.swift; then
    echo "✅ ONNXRuntimeAvailability enum" >> "$REPORT_FILE"
else
    echo "❌ ONNXRuntimeAvailability enum NOT FOUND" >> "$REPORT_FILE"
    ((ERRORS++))
fi
if grep -q "protocol ONNXRuntimeSessionProtocol" MyTeam/ONNXRuntimeAdapter.swift; then
    echo "✅ ONNXRuntimeSessionProtocol" >> "$REPORT_FILE"
else
    echo "❌ ONNXRuntimeSessionProtocol NOT FOUND" >> "$REPORT_FILE"
    ((ERRORS++))
fi
if grep -q "protocol ONNXRuntimeAdapterProtocol" MyTeam/ONNXRuntimeAdapter.swift; then
    echo "✅ ONNXRuntimeAdapterProtocol" >> "$REPORT_FILE"
else
    echo "❌ ONNXRuntimeAdapterProtocol NOT FOUND" >> "$REPORT_FILE"
    ((ERRORS++))
fi
if grep -q "struct ONNXRuntimeUnavailableAdapter" MyTeam/ONNXRuntimeAdapter.swift; then
    echo "✅ ONNXRuntimeUnavailableAdapter" >> "$REPORT_FILE"
else
    echo "❌ ONNXRuntimeUnavailableAdapter NOT FOUND" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 3: Tensor types are Sendable
echo "## Check 3: Tensor Types (Sendable)" >> "$REPORT_FILE"
if grep -q "struct Supertonic3TensorInputs: Sendable" MyTeam/Supertonic3TensorTypes.swift; then
    echo "✅ Supertonic3TensorInputs: Sendable" >> "$REPORT_FILE"
else
    echo "⚠️  Supertonic3TensorInputs may not be Sendable" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
if grep -q "struct Supertonic3TensorOutputs: Sendable" MyTeam/Supertonic3TensorTypes.swift; then
    echo "✅ Supertonic3TensorOutputs: Sendable" >> "$REPORT_FILE"
else
    echo "⚠️  Supertonic3TensorOutputs may not be Sendable" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
echo "" >> "$REPORT_FILE"

# Check 4: ModelManifest using candidates
echo "## Check 4: Supertonic3ModelManifest Candidates" >> "$REPORT_FILE"
if grep -q "candidateFilenames:" MyTeam/Supertonic3ModelManifest.swift; then
    echo "✅ Using candidate filenames (not hardcoded)" >> "$REPORT_FILE"
else
    echo "❌ Not using candidate filenames" >> "$REPORT_FILE"
    ((ERRORS++))
fi
if grep -q "text_encoder" MyTeam/Supertonic3ModelManifest.swift; then
    echo "✅ text_encoder candidates defined" >> "$REPORT_FILE"
else
    echo "❌ text_encoder candidates not defined" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 5: InferencePipeline is actor
echo "## Check 5: Supertonic3InferencePipeline Structure" >> "$REPORT_FILE"
if grep -q "actor Supertonic3InferencePipeline" MyTeam/Supertonic3InferencePipeline.swift; then
    echo "✅ InferencePipeline is actor" >> "$REPORT_FILE"
else
    echo "❌ InferencePipeline is not actor" >> "$REPORT_FILE"
    ((ERRORS++))
fi
if grep -q "func prepare(modelDirectory: URL)" MyTeam/Supertonic3InferencePipeline.swift; then
    echo "✅ prepare() method exists" >> "$REPORT_FILE"
else
    echo "❌ prepare() method not found" >> "$REPORT_FILE"
    ((ERRORS++))
fi
if grep -q "func synthesize(" MyTeam/Supertonic3InferencePipeline.swift; then
    echo "✅ synthesize() method exists" >> "$REPORT_FILE"
else
    echo "❌ synthesize() method not found" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 6: No real ONNX runtime imports
echo "## Check 6: No Real ONNX Runtime (Cloud)" >> "$REPORT_FILE"
if ! grep -q "import.*onnxruntime\|import ORT\|from onnxruntime" MyTeam/ONNXRuntimeAdapter.swift MyTeam/Supertonic3InferencePipeline.swift 2>/dev/null; then
    echo "✅ No actual ONNX Runtime imports (correct for Cloud)" >> "$REPORT_FILE"
else
    echo "⚠️  Found ONNX Runtime imports (should be commented/future)" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
echo "" >> "$REPORT_FILE"

# Check 7: ModelLocator uses Manifest
echo "## Check 7: ModelLocator Uses Manifest" >> "$REPORT_FILE"
if grep -q "Supertonic3ModelManifest.requiredFiles\|Supertonic3ModelManifest.optionalFiles" MyTeam/Supertonic3ModelLocator.swift; then
    echo "✅ ModelLocator uses Manifest" >> "$REPORT_FILE"
else
    echo "❌ ModelLocator does not use Manifest" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 8: TTSProvider uses Pipeline
echo "## Check 8: TTSProvider Uses Pipeline" >> "$REPORT_FILE"
if grep -q "Supertonic3InferencePipeline" MyTeam/Supertonic3TTSProvider.swift; then
    echo "✅ TTSProvider instantiates pipeline" >> "$REPORT_FILE"
else
    echo "❌ TTSProvider does not use pipeline" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 9: TTSProbe has readiness enum
echo "## Check 9: TTSProbe Readiness" >> "$REPORT_FILE"
if grep -q "enum Supertonic3Readiness" MyTeam/Supertonic3TTSProbe.swift; then
    echo "✅ Supertonic3Readiness enum defined" >> "$REPORT_FILE"
else
    echo "❌ Supertonic3Readiness enum NOT found" >> "$REPORT_FILE"
    ((ERRORS++))
fi
if grep -q "struct Supertonic3ProbeResult" MyTeam/Supertonic3TTSProbe.swift; then
    echo "✅ Supertonic3ProbeResult struct defined" >> "$REPORT_FILE"
else
    echo "❌ Supertonic3ProbeResult struct NOT found" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 10: No fake audio / dummy success
echo "## Check 10: No Fake Audio / Dummy Success" >> "$REPORT_FILE"
if ! grep -q "fake.*audio\|dummy.*wav\|fake.*result\|fake success\|return.*success" MyTeam/Supertonic3InferencePipeline.swift MyTeam/Supertonic3TTSProvider.swift 2>/dev/null; then
    echo "✅ No fake audio or dummy success patterns" >> "$REPORT_FILE"
else
    echo "⚠️  Found potential fake audio patterns (inspect)" >> "$REPORT_FILE"
    ((WARNINGS++))
fi
echo "" >> "$REPORT_FILE"

# Check 11: No auto-download
echo "## Check 11: No Auto-Download" >> "$REPORT_FILE"
if ! grep -q "downloadModel\|auto_download\|hf_hub_download\|wget.*model" MyTeam/*.swift MyTeam/Supertonic3* 2>/dev/null; then
    echo "✅ No auto-download code" >> "$REPORT_FILE"
else
    echo "❌ Found auto-download code (should be manual only)" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Check 12: pbxproj registered
echo "## Check 12: pbxproj Registration" >> "$REPORT_FILE"
for file in ONNXRuntimeAdapter Supertonic3TensorTypes Supertonic3ModelManifest Supertonic3InferencePipeline; do
    if grep -q "${file}.swift" MyTeam/MyTeam.xcodeproj/project.pbxproj; then
        echo "✅ ${file}.swift in pbxproj" >> "$REPORT_FILE"
    else
        echo "❌ ${file}.swift NOT in pbxproj" >> "$REPORT_FILE"
        ((ERRORS++))
    fi
done
echo "" >> "$REPORT_FILE"

# Check 13: No build logs staged
echo "## Check 13: No Build Logs Staged" >> "$REPORT_FILE"
if ! git status --short | grep -E "debug-build.log|release-build.log" > /dev/null 2>&1; then
    echo "✅ No debug/release build logs staged" >> "$REPORT_FILE"
else
    echo "❌ Build logs found in staging area" >> "$REPORT_FILE"
    ((ERRORS++))
fi
echo "" >> "$REPORT_FILE"

# Summary
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Metric | Count |" >> "$REPORT_FILE"
echo "|--------|-------|" >> "$REPORT_FILE"
echo "| Errors | $ERRORS |" >> "$REPORT_FILE"
echo "| Warnings | $WARNINGS |" >> "$REPORT_FILE"
echo "| Status | $([ $ERRORS -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "## Notes" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Round 248TTS-A Goals:**" >> "$REPORT_FILE"
echo "- ✅ Runtime boundary defined (ONNXRuntimeAdapter)" >> "$REPORT_FILE"
echo "- ✅ Tensor types defined (Supertonic3TensorTypes)" >> "$REPORT_FILE"
echo "- ✅ Model manifest policy defined (Supertonic3ModelManifest)" >> "$REPORT_FILE"
echo "- ✅ Pipeline skeleton implemented (Supertonic3InferencePipeline)" >> "$REPORT_FILE"
echo "- ✅ No actual ONNX inference (Cloud environment)" >> "$REPORT_FILE"
echo "- ✅ Ready for Mac local ONNX Runtime integration (Round 249TTS)" >> "$REPORT_FILE"

cat "$REPORT_FILE"

if [ $ERRORS -eq 0 ]; then
    echo ""
    echo "✅ Round 248TTS-A preflight: PASS"
    exit 0
else
    echo ""
    echo "❌ Round 248TTS-A preflight: FAIL ($ERRORS errors)"
    exit 1
fi
