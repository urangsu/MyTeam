#!/usr/bin/env python3
"""Validate MyTeam skill package manifests."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = ROOT / "skills"

REQUIRED_FIELDS = {
    "id",
    "version",
    "kind",
    "display_name",
    "description",
    "source_repo",
    "execution_modes",
    "required_credentials",
    "input_schema",
    "output_schema",
    "failure_modes",
    "source_policy",
    "ui",
    "rules",
}

ALLOWED_KINDS = {
    "localSwift",
    "directREST",
    "myTeamProxy",
    "externalMCP",
    "disabled",
}

PROVIDER_CREDENTIAL_FIELDS = {
    "openAI": {"apiKey"},
    "gemini": {"apiKey"},
    "anthropic": {"apiKey"},
    "openRouter": {"apiKey"},
    "kmaWeather": {"serviceKey"},
    "naverNews": {"clientID", "clientSecret"},
    "dartDisclosure": {"apiKey"},
}


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise ValueError(f"{path}: invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}") from exc


def non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def non_empty_list(value: Any) -> bool:
    return isinstance(value, list) and len(value) > 0


def validate_required_fields(path: Path, manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for field in sorted(REQUIRED_FIELDS):
        if field not in manifest:
            errors.append(f"{path}: missing required field {field}")
    return errors


def validate_credentials(path: Path, manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    credentials = manifest.get("required_credentials")
    if not isinstance(credentials, list):
        return [f"{path}: required_credentials must be an array"]

    for index, credential in enumerate(credentials):
        prefix = f"{path}: required_credentials[{index}]"
        if not isinstance(credential, dict):
            errors.append(f"{prefix} must be an object")
            continue

        credential_type = credential.get("type")
        if credential_type == "provider":
            provider = credential.get("provider")
            fields = credential.get("fields")
            if provider not in PROVIDER_CREDENTIAL_FIELDS:
                errors.append(f"{prefix}: unknown provider {provider!r}")
                continue
            if not isinstance(fields, list) or not all(non_empty_string(field) for field in fields):
                errors.append(f"{prefix}: provider credentials require non-empty fields")
                continue
            actual = set(fields)
            expected = PROVIDER_CREDENTIAL_FIELDS[provider]
            if actual != expected:
                errors.append(
                    f"{prefix}: fields for {provider} must match ProviderCredential schema "
                    f"{sorted(expected)}, got {sorted(actual)}"
                )
        elif credential_type == "external":
            if not non_empty_string(credential.get("id")):
                errors.append(f"{prefix}: external credentials require id")
            if not non_empty_string(credential.get("description")):
                errors.append(f"{prefix}: external credentials require description")
        else:
            errors.append(f"{prefix}: type must be provider or external")

    return errors


def validate_manifest(path: Path) -> list[str]:
    manifest = load_json(path)
    errors: list[str] = []

    if not isinstance(manifest, dict):
        return [f"{path}: root must be an object"]

    errors.extend(validate_required_fields(path, manifest))

    kind = manifest.get("kind")
    if kind not in ALLOWED_KINDS:
        errors.append(f"{path}: kind must be one of {sorted(ALLOWED_KINDS)}, got {kind!r}")

    for field in ("id", "version", "display_name", "description", "source_repo"):
        if field in manifest and not non_empty_string(manifest.get(field)):
            errors.append(f"{path}: {field} must be a non-empty string")

    if "failure_modes" in manifest and not non_empty_list(manifest.get("failure_modes")):
        errors.append(f"{path}: failure_modes must not be empty")

    if "rules" in manifest and not non_empty_list(manifest.get("rules")):
        errors.append(f"{path}: rules must not be empty")

    if "source_policy" in manifest:
        source_policy = manifest.get("source_policy")
        if not isinstance(source_policy, dict):
            errors.append(f"{path}: source_policy must be an object")
        elif source_policy.get("requires_sources") is True and not non_empty_string(source_policy.get("verified_label_requires")):
            errors.append(f"{path}: source_policy.verified_label_requires is required when sources are required")

    runtime = manifest.get("runtime")
    if runtime is not None:
        if not isinstance(runtime, dict):
            errors.append(f"{path}: runtime must be an object")
        else:
            if runtime.get("auto_load") is True:
                errors.append(f"{path}: reference packages must not set runtime.auto_load=true")
            if runtime.get("user_visible_enabled") is True:
                errors.append(f"{path}: reference packages must not set runtime.user_visible_enabled=true")

    errors.extend(validate_credentials(path, manifest))

    return errors


def main() -> int:
    if not SKILLS_DIR.exists():
        print(f"Skill package validation failed: {SKILLS_DIR} does not exist")
        return 1

    manifest_paths = sorted(SKILLS_DIR.glob("*/skill.json"))
    if not manifest_paths:
        print("Skill package validation failed: no skills/*/skill.json files found")
        return 1

    errors: list[str] = []
    for path in manifest_paths:
        errors.extend(validate_manifest(path))

    if errors:
        print("Skill package validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Skill package validation passed: {len(manifest_paths)} manifests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
