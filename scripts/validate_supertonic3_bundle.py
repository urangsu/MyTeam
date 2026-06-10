#!/usr/bin/env python3
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_ROOT = ROOT / "MyTeam" / "Resources" / "Supertonic3"

REQUIRED_ONNX_FILES = [
    "text_encoder.onnx",
    "duration_predictor.onnx",
    "vector_estimator.onnx",
    "vocoder.onnx",
]

REQUIRED_VOICE_STYLES = [
    "M1.json",
    "M2.json",
    "M3.json",
    "M4.json",
    "M5.json",
    "F1.json",
    "F2.json",
    "F3.json",
    "F4.json",
    "F5.json",
]


def is_required_mode(argv: list[str]) -> bool:
    return "--require-bundle" in argv or os.environ.get("MYTEAM_REQUIRE_SUPERTONIC3_BUNDLE") == "1"


def missing_files() -> list[str]:
    missing: list[str] = []
    for filename in REQUIRED_ONNX_FILES:
        path = RESOURCE_ROOT / "onnx" / filename
        if not path.is_file():
            missing.append(str(path.relative_to(ROOT)))
    for filename in REQUIRED_VOICE_STYLES:
        path = RESOURCE_ROOT / "voice_styles" / filename
        if not path.is_file():
            missing.append(str(path.relative_to(ROOT)))
    return missing


def main() -> None:
    missing = missing_files()
    if not missing:
        print("PASS: Supertonic3 bundled model resources present")
        return

    if not is_required_mode(sys.argv[1:]):
        print(
            "SKIP: Supertonic3 bundled model resources are not present; "
            "set MYTEAM_REQUIRE_SUPERTONIC3_BUNDLE=1 for App Store RC enforcement."
        )
        return

    print("FAIL: Supertonic3 App Store RC bundle is incomplete", file=sys.stderr)
    for item in missing:
        print(f"  missing: {item}", file=sys.stderr)
    raise SystemExit(1)


if __name__ == "__main__":
    main()
