#!/usr/bin/env python3
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("validate_release_qa_evidence.py")
SPEC = importlib.util.spec_from_file_location("validate_release_qa_evidence", MODULE_PATH)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class ReleaseQAEvidenceValidatorTests(unittest.TestCase):
    def make_doc(self, root: Path, tested_commit: str) -> Path:
        path = root / "manual.md"
        path.write_text(
            "\n".join(
                [
                    f"- tested_commit: `{tested_commit}`",
                    "- tested_build: `MyTeam Release.app`",
                    "- tested_at: `2026-07-17 00:00 KST`",
                    "- tester: `Codex runtime QA`",
                    "- profile: `Release`",
                    "- configuration: `Release`",
                    "- architecture: `arm64 x86_64`",
                    "- xcode_version: `17.5`",
                    "- artifact_sha256: `abc123`",
                ]
            ),
            encoding="utf-8",
        )
        return path

    def validate_with_changed_paths(self, changed_paths: list[str]) -> list[str]:
        with tempfile.TemporaryDirectory(dir=VALIDATOR.ROOT) as directory:
            path = self.make_doc(Path(directory), "tested-sha")
            relative = str(path.relative_to(VALIDATOR.ROOT))
            with (
                patch.object(VALIDATOR, "MANUAL_QA_DOCS", {relative}),
                patch.object(VALIDATOR, "worktree_is_clean", return_value=True),
                patch.object(VALIDATOR, "current_head", return_value="evidence-sha"),
                patch.object(
                    VALIDATOR,
                    "changed_paths_since_tested_commit",
                    return_value=changed_paths,
                    create=True,
                ),
            ):
                return VALIDATOR.validate_doc(path, [], strict=True, release_strict=False)

    def test_strict_accepts_evidence_only_commits_after_tested_build(self):
        failures = self.validate_with_changed_paths(["docs/qa/HomeSurfaceManualQA.md"])

        self.assertFalse(any("tested_commit" in failure for failure in failures), failures)

    def test_strict_rejects_product_changes_after_tested_build(self):
        failures = self.validate_with_changed_paths(["MyTeam/AgentWindowManager.swift"])

        self.assertTrue(
            any("product source changed after tested_commit" in failure for failure in failures),
            failures,
        )


if __name__ == "__main__":
    unittest.main()
