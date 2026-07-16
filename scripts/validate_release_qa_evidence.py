#!/usr/bin/env python3
import argparse
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


QA_DOCS: dict[str, list[str]] = {
    "docs/qa/MainProductStabilizationMergeGate.md": [
        "MG-STATIC-001",
        "MG-BUILD-001",
        "MG-BUILD-002",
    ],
    "docs/qa/AppTerminationManualQA.md": [
        "APPTERM-001",
        "APPTERM-002",
        "APPTERM-003",
        "APPTERM-004",
        "APPTERM-005",
        "APPTERM-006",
    ],
    "docs/qa/NaturalWorkE2EManualQA.md": [
        "NW-001",
        "NW-002",
        "NW-003",
        "NW-004",
        "NW-005",
        "NW-006",
        "NW-007",
        "NW-008",
        "NW-009",
        "NW-010",
        "NW-011",
        "NW-012",
        "NW-013",
        "NW-CONC-001",
        "NW-CONC-002",
        "NW-CONC-003",
        "NW-CONC-004",
        "NW-CONC-005",
        "NW-CONC-006",
    ],
    "docs/qa/ArtifactReopenManualQA.md": [
        "ART-001",
        "ART-002",
        "ART-003",
        "ART-004",
        "ART-005",
        "ART-006",
        "ART-007",
        "ART-008",
        "ART-009",
    ],
    "docs/qa/HomeSurfaceManualQA.md": [
        "HOME-001",
        "HOME-002",
        "HOME-003",
        "HOME-004",
        "HOME-005",
        "HOME-006",
    ],
    "docs/qa/LiveProviderQAMatrix.md": [
        "GOOGLE-001",
        "GOOGLE-002",
        "GOOGLE-003",
        "GOOGLE-004",
        "GOOGLE-005",
        "GOOGLE-006",
        "FIN-001",
        "FIN-002",
        "FIN-003",
        "FIN-004",
        "FIN-005",
        "DART-001",
        "DART-002",
        "DART-003",
        "DART-004",
        "KMA-001",
        "KMA-002",
        "KMA-003",
        "NEWS-001",
        "NEWS-002",
        "NEWS-003",
        "LAW-001",
        "LAW-002",
        "LAW-003",
        "WORKER-001",
        "WORKER-002",
    ],
}


STRICT_REQUIRED_PASS_PREFIXES = (
    "MG-",
    "APPTERM-",
    "NW-",
    "ART-",
    "HOME-",
)

RELEASE_REQUIRED_PROVIDER_PREFIXES = (
    "GOOGLE-",
    "FIN-",
    "DART-",
    "KMA-",
    "NEWS-",
    "LAW-",
    "WORKER-",
)

STATUS_VALUES = {"PASS", "FAIL", "BLOCKED", "DISABLED"}

MANUAL_QA_DOCS = {
    "docs/qa/AppTerminationManualQA.md",
    "docs/qa/NaturalWorkE2EManualQA.md",
    "docs/qa/ArtifactReopenManualQA.md",
    "docs/qa/HomeSurfaceManualQA.md",
}

REQUIRED_EVIDENCE_FIELDS = (
    "tested_commit",
    "tested_build",
    "tested_at",
    "tester",
    "profile",
)

STRICT_BUILD_METADATA_FIELDS = (
    "configuration",
    "architecture",
    "xcode_version",
    "artifact_sha256",
)

MANUAL_EVIDENCE_FILE_PATTERN = re.compile(
    r"docs/qa/evidence/[^\s`|]+",
    re.I,
)

MANUAL_EVIDENCE_COMMAND_PATTERN = re.compile(
    r"(?:python3\s+scripts/[^\s`|]+|xcodebuild\b|pgrep\b|osascript\b)",
    re.I,
)

PYTHON_EVIDENCE_SCRIPT_PATTERN = re.compile(
    r"python3\s+(scripts/[^\s`|]+)",
    re.I,
)

SHA256_PATTERN = re.compile(r"[0-9a-f]{64}", re.I)


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def find_case_row(text: str, case_id: str) -> tuple[str, list[str]] | None:
    for line in text.splitlines():
        if f"| {case_id} " in line or f"|{case_id}|" in line or re.search(rf"\b{re.escape(case_id)}\b", line):
            cells = split_table_row(line)
            if cells and cells[0] == case_id:
                return line, cells
    return None


def status_for(cells: list[str]) -> str | None:
    for cell in cells:
        normalized = cell.strip().upper()
        if normalized in STATUS_VALUES:
            return normalized
    return None


def has_reason_or_next_action(cells: list[str]) -> bool:
    joined = " ".join(cells).strip()
    return bool(re.search(r"\b(Reason|Next|Fix|Retest|재현|사유|다음|조치)\b", joined, re.I))


def metadata_value(text: str, field: str) -> str | None:
    match = re.search(rf"^\s*-\s*{re.escape(field)}\s*:\s*`?([^`\n]+)`?", text, re.M)
    if not match:
        return None
    return match.group(1).strip()


def current_head() -> str:
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def worktree_is_clean() -> bool:
    status = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)
    return status.strip() == ""


def changed_paths_since_tested_commit(tested_commit: str) -> list[str] | None:
    commit_exists = subprocess.run(
        ["git", "cat-file", "-e", f"{tested_commit}^{{commit}}"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if commit_exists.returncode != 0:
        return None

    is_ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", tested_commit, "HEAD"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if is_ancestor.returncode != 0:
        return None

    output = subprocess.check_output(
        ["git", "diff", "--name-only", f"{tested_commit}..HEAD"],
        cwd=ROOT,
        text=True,
    )
    return [line.strip() for line in output.splitlines() if line.strip()]


def is_qa_evidence_path(path: str) -> bool:
    return path.startswith("docs/qa/") or path == "docs/backlog/myteam_product_backlog.json"


def validate_manual_pass_evidence(joined_cells: str, relative_path: str, case_id: str) -> list[str]:
    failures: list[str] = []
    evidence_root = (ROOT / "docs/qa/evidence").resolve()
    evidence_files = MANUAL_EVIDENCE_FILE_PATTERN.findall(joined_cells)
    evidence_commands = MANUAL_EVIDENCE_COMMAND_PATTERN.findall(joined_cells)
    if not evidence_files and not evidence_commands:
        failures.append(f"{relative_path} case {case_id} is PASS without durable evidence path or command")

    for reference in evidence_files:
        candidate = (ROOT / reference).resolve()
        if not candidate.is_relative_to(evidence_root):
            failures.append(
                f"{relative_path} case {case_id} evidence path escapes docs/qa/evidence: {reference}"
            )
        elif not candidate.is_file():
            failures.append(
                f"{relative_path} case {case_id} evidence file does not exist: {reference}"
            )

    scripts_root = (ROOT / "scripts").resolve()
    for script_reference in PYTHON_EVIDENCE_SCRIPT_PATTERN.findall(joined_cells):
        candidate = (ROOT / script_reference).resolve()
        if not candidate.is_relative_to(scripts_root) or not candidate.is_file():
            failures.append(
                f"{relative_path} case {case_id} evidence script does not exist: {script_reference}"
            )
    return failures


def validate_doc(path: Path, case_ids: list[str], strict: bool, release_strict: bool) -> list[str]:
    failures: list[str] = []
    if not path.exists():
        return [f"missing QA document: {path.relative_to(ROOT)}"]

    text = path.read_text()
    relative_path = str(path.relative_to(ROOT))
    if relative_path in MANUAL_QA_DOCS:
        for field in REQUIRED_EVIDENCE_FIELDS:
            if not re.search(rf"^\s*-\s*{re.escape(field)}\s*:", text, re.M):
                failures.append(f"{relative_path} missing evidence metadata field {field}")
        if strict:
            if not worktree_is_clean():
                failures.append(f"{relative_path} cannot be accepted in --strict mode while the worktree is dirty")
            tested_commit = metadata_value(text, "tested_commit")
            tested_build = metadata_value(text, "tested_build") or ""
            if tested_commit != current_head():
                changed_paths = changed_paths_since_tested_commit(tested_commit or "")
                if changed_paths is None:
                    failures.append(
                        f"{relative_path} tested_commit must identify current HEAD or one of its ancestors in --strict mode"
                    )
                else:
                    product_changes = [changed for changed in changed_paths if not is_qa_evidence_path(changed)]
                    if product_changes:
                        failures.append(
                            f"{relative_path} product source changed after tested_commit: {', '.join(product_changes)}"
                        )
            if re.search(r"\b(not run|pending|unknown|n/a)\b", tested_build, re.I):
                failures.append(f"{relative_path} tested_build must reference an actual tested build in --strict mode")
            for field in STRICT_BUILD_METADATA_FIELDS:
                value = metadata_value(text, field)
                if not value or re.search(r"\b(not run|pending|unknown|n/a)\b", value, re.I):
                    failures.append(f"{relative_path} strict build metadata field {field} must be an actual tested value")
            artifact_sha256 = metadata_value(text, "artifact_sha256") or ""
            if not SHA256_PATTERN.fullmatch(artifact_sha256):
                failures.append(f"{relative_path} artifact_sha256 must be exactly 64 hexadecimal characters")

    forbidden_release_tag_patterns = [
        r"release tag\s*:\s*PASS",
        r"release tag\s*가능",
        r"Release tag decision:\s*PASS",
        r"Release tag decision:\s*가능",
    ]
    for pattern in forbidden_release_tag_patterns:
        if re.search(pattern, text, re.I):
            failures.append(f"{path.relative_to(ROOT)} claims release tag is possible")

    incomplete = any(status in text for status in ("BLOCKED", "FAIL"))
    if incomplete and re.search(r"release candidate\s*:\s*PASS|RC\s*:\s*PASS|Release candidate decision:\s*PASS", text, re.I):
        failures.append(f"{path.relative_to(ROOT)} claims release candidate is possible while QA is incomplete")

    for case_id in case_ids:
        row = find_case_row(text, case_id)
        if row is None:
            failures.append(f"{path.relative_to(ROOT)} missing case {case_id}")
            continue
        _, cells = row
        status = status_for(cells)
        if status is None:
            failures.append(f"{path.relative_to(ROOT)} case {case_id} has no PASS/FAIL/BLOCKED status")
            continue
        if status in {"FAIL", "BLOCKED"} and not has_reason_or_next_action(cells):
            failures.append(f"{path.relative_to(ROOT)} case {case_id} is {status} without reason or next action")
        if strict and case_id.startswith(STRICT_REQUIRED_PASS_PREFIXES) and status != "PASS":
            failures.append(f"{path.relative_to(ROOT)} case {case_id} must be PASS in --strict mode, found {status}")
        if strict and status == "PASS" and relative_path in MANUAL_QA_DOCS:
            joined = " ".join(cells)
            if "Pending" in joined or "pending" in joined:
                failures.append(f"{path.relative_to(ROOT)} case {case_id} is PASS but still contains pending evidence text")
            failures.extend(validate_manual_pass_evidence(joined, relative_path, case_id))
        if release_strict and case_id.startswith(RELEASE_REQUIRED_PROVIDER_PREFIXES) and status not in {"PASS", "DISABLED"}:
            failures.append(
                f"{path.relative_to(ROOT)} case {case_id} must be PASS or DISABLED in --release-strict mode, found {status}"
            )

    return failures


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate release QA evidence documents.")
    parser.add_argument("--strict", action="store_true", help="Require release-candidate manual QA cases to be PASS.")
    parser.add_argument(
        "--release-strict",
        action="store_true",
        help="Require live provider/release-surface cases to be PASS or DISABLED.",
    )
    args = parser.parse_args()

    failures: list[str] = []
    for relative, case_ids in QA_DOCS.items():
        failures.extend(validate_doc(ROOT / relative, case_ids, args.strict, args.release_strict))

    if failures:
        print("FAIL: release QA evidence validation", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        raise SystemExit(1)

    if args.release_strict:
        mode = "release-strict"
    elif args.strict:
        mode = "strict"
    else:
        mode = "non-strict"
    print(f"PASS: release QA evidence validation ({mode})")


if __name__ == "__main__":
    main()
