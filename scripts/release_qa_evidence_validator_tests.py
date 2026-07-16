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
    def make_doc(
        self,
        root: Path,
        tested_commit: str,
        artifact_sha256: str = "a" * 64,
        rows: list[str] | None = None,
    ) -> Path:
        path = root / "manual.md"
        lines = [
            f"- tested_commit: `{tested_commit}`",
            "- tested_build: `MyTeam Release.app`",
            "- tested_at: `2026-07-17 00:00 KST`",
            "- tester: `Codex runtime QA`",
            "- profile: `Release`",
            "- configuration: `Release`",
            "- architecture: `arm64 x86_64`",
            "- xcode_version: `17.5`",
            f"- artifact_sha256: `{artifact_sha256}`",
        ]
        lines.extend(rows or [])
        path.write_text("\n".join(lines), encoding="utf-8")
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

    def test_strict_rejects_malformed_artifact_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.make_doc(root, "tested-sha", artifact_sha256="abc123")
            with (
                patch.object(VALIDATOR, "ROOT", root),
                patch.object(VALIDATOR, "MANUAL_QA_DOCS", {"manual.md"}),
                patch.object(VALIDATOR, "worktree_is_clean", return_value=True),
                patch.object(VALIDATOR, "current_head", return_value="tested-sha"),
            ):
                failures = VALIDATOR.validate_doc(path, [], strict=True, release_strict=False)

        self.assertTrue(any("artifact_sha256" in failure for failure in failures), failures)

    def test_strict_rejects_missing_manual_evidence_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.make_doc(
                root,
                "tested-sha",
                rows=[
                    "| Case ID | PASS / FAIL / BLOCKED | Evidence |",
                    "| --- | --- | --- |",
                    "| CASE-001 | PASS | `docs/qa/evidence/missing.log` |",
                ],
            )
            with (
                patch.object(VALIDATOR, "ROOT", root),
                patch.object(VALIDATOR, "MANUAL_QA_DOCS", {"manual.md"}),
                patch.object(VALIDATOR, "worktree_is_clean", return_value=True),
                patch.object(VALIDATOR, "current_head", return_value="tested-sha"),
            ):
                failures = VALIDATOR.validate_doc(path, ["CASE-001"], strict=True, release_strict=False)

        self.assertTrue(any("evidence file does not exist" in failure for failure in failures), failures)

    def test_strict_rejects_bare_evidence_filename(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.make_doc(
                root,
                "tested-sha",
                rows=[
                    "| Case ID | PASS / FAIL / BLOCKED | Evidence |",
                    "| --- | --- | --- |",
                    "| CASE-001 | PASS | `missing.png` |",
                ],
            )
            with (
                patch.object(VALIDATOR, "ROOT", root),
                patch.object(VALIDATOR, "MANUAL_QA_DOCS", {"manual.md"}),
                patch.object(VALIDATOR, "worktree_is_clean", return_value=True),
                patch.object(VALIDATOR, "current_head", return_value="tested-sha"),
            ):
                failures = VALIDATOR.validate_doc(path, ["CASE-001"], strict=True, release_strict=False)

        self.assertTrue(any("durable evidence path or command" in failure for failure in failures), failures)

    def test_strict_rejects_missing_evidence_script(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.make_doc(
                root,
                "tested-sha",
                rows=[
                    "| Case ID | PASS / FAIL / BLOCKED | Evidence |",
                    "| --- | --- | --- |",
                    "| CASE-001 | PASS | `python3 scripts/missing_validator.py` |",
                ],
            )
            with (
                patch.object(VALIDATOR, "ROOT", root),
                patch.object(VALIDATOR, "MANUAL_QA_DOCS", {"manual.md"}),
                patch.object(VALIDATOR, "worktree_is_clean", return_value=True),
                patch.object(VALIDATOR, "current_head", return_value="tested-sha"),
            ):
                failures = VALIDATOR.validate_doc(path, ["CASE-001"], strict=True, release_strict=False)

        self.assertTrue(any("evidence script does not exist" in failure for failure in failures), failures)

    def test_strict_accepts_existing_manual_evidence_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            evidence = root / "docs/qa/evidence/proof.log"
            evidence.parent.mkdir(parents=True)
            evidence.write_text("runtime proof", encoding="utf-8")
            path = self.make_doc(
                root,
                "tested-sha",
                rows=[
                    "| Case ID | PASS / FAIL / BLOCKED | Evidence |",
                    "| --- | --- | --- |",
                    "| CASE-001 | PASS | `docs/qa/evidence/proof.log` |",
                ],
            )
            with (
                patch.object(VALIDATOR, "ROOT", root),
                patch.object(VALIDATOR, "MANUAL_QA_DOCS", {"manual.md"}),
                patch.object(VALIDATOR, "worktree_is_clean", return_value=True),
                patch.object(VALIDATOR, "current_head", return_value="tested-sha"),
            ):
                failures = VALIDATOR.validate_doc(path, ["CASE-001"], strict=True, release_strict=False)

        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
