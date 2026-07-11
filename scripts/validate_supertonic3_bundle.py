#!/usr/bin/env python3
import hashlib
import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_ROOT = ROOT / "MyTeam" / "Resources" / "Supertonic3"
INTEGRITY_MANIFEST = RESOURCE_ROOT / "model-integrity.json"

REQUIRED_ONNX_FILES = [
    "text_encoder.onnx",
    "duration_predictor.onnx",
    "vector_estimator.onnx",
    "vocoder.onnx",
    "unicode_indexer.json",
    "tts.json",
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
    if "--require-bundle" in argv:
        return True
    if os.environ.get("MYTEAM_REQUIRE_SUPERTONIC3_BUNDLE") == "1":
        return True
    if "--profile" in argv:
        index = argv.index("--profile")
        if index + 1 < len(argv):
            return argv[index + 1].lower() in {"appstore", "app-store", "release", "rc"}
    return False


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


def validate_integrity() -> list[str]:
    failures: list[str] = []
    if not INTEGRITY_MANIFEST.is_file():
        return [str(INTEGRITY_MANIFEST.relative_to(ROOT)) + ": missing integrity manifest"]

    try:
        manifest = json.loads(INTEGRITY_MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"{INTEGRITY_MANIFEST.relative_to(ROOT)}: invalid JSON: {error}"]

    if manifest.get("schema_version") != 1:
        failures.append("model-integrity.json: schema_version must be 1")
    if manifest.get("sample_rate") != 44100:
        failures.append("model-integrity.json: sample_rate must be 44100")

    entries = manifest.get("files")
    if not isinstance(entries, list) or not entries:
        return failures + ["model-integrity.json: files must be a non-empty array"]

    expected_paths = {
        *(f"onnx/{name}" for name in REQUIRED_ONNX_FILES),
        *(f"voice_styles/{name}" for name in REQUIRED_VOICE_STYLES),
    }
    manifest_paths = {entry.get("path") for entry in entries if isinstance(entry, dict)}
    for missing_path in sorted(expected_paths - manifest_paths):
        failures.append(f"model-integrity.json: missing entry {missing_path}")

    for entry in entries:
        if not isinstance(entry, dict):
            failures.append("model-integrity.json: each file entry must be an object")
            continue
        relative_path = entry.get("path")
        expected_size = entry.get("size")
        expected_hash = entry.get("sha256")
        if not isinstance(relative_path, str) or relative_path.startswith("/") or ".." in Path(relative_path).parts:
            failures.append(f"model-integrity.json: unsafe path {relative_path!r}")
            continue
        path = RESOURCE_ROOT / relative_path
        if not path.is_file():
            failures.append(f"{relative_path}: missing")
            continue
        if path.stat().st_size != expected_size:
            failures.append(f"{relative_path}: size mismatch")
            continue
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected_hash:
            failures.append(f"{relative_path}: sha256 mismatch")
    return failures


def main() -> None:
    missing = missing_files()
    integrity_failures = validate_integrity() if not missing else []
    if not missing and not integrity_failures:
        print("PASS: Supertonic3 bundled model resources and integrity verified")
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
    for item in integrity_failures:
        print(f"  integrity: {item}", file=sys.stderr)
    raise SystemExit(1)


if __name__ == "__main__":
    main()
