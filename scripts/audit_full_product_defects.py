#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QA_DOCS = [
    ROOT / "docs/qa/AppTerminationManualQA.md",
    ROOT / "docs/qa/NaturalWorkE2EManualQA.md",
    ROOT / "docs/qa/ArtifactReopenManualQA.md",
    ROOT / "docs/qa/HomeSurfaceManualQA.md",
    ROOT / "docs/qa/LiveProviderQAMatrix.md",
    ROOT / "docs/qa/MainProductStabilizationMergeGate.md",
    ROOT / "docs/qa/ProductCompletenessInventory.md",
    ROOT / "docs/qa/FullProductDefectAudit.md",
]

STALE_COMMIT_DOCS = [
    ROOT / "docs/qa/AppTerminationManualQA.md",
    ROOT / "docs/qa/NaturalWorkE2EManualQA.md",
    ROOT / "docs/qa/ArtifactReopenManualQA.md",
    ROOT / "docs/qa/HomeSurfaceManualQA.md",
]

BLOCKING_STATUSES = {"FAIL", "BLOCKED", "DISABLED", "STALE", "PARTIAL", "OPEN", "liveButNeedsManualQA"}


def current_head() -> str:
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def table_rows(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and re.match(r"^[A-Z]+[-A-Z0-9]*-\d+", cells[0]):
            rows.append(cells)
    return rows


def row_status(row: list[str]) -> str | None:
    for cell in row:
        if cell in BLOCKING_STATUSES:
            return cell
    return None


def run_worker_health() -> tuple[bool, str]:
    worker = subprocess.run(
        ["python3", "scripts/validate_worker_production_health.py"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    output = "\n".join(part for part in [worker.stdout.strip(), worker.stderr.strip()] if part)
    return worker.returncode == 0, output


def main() -> int:
    head = current_head()
    unresolved: list[str] = []
    stale: list[str] = []

    for path in QA_DOCS:
        if not path.exists():
            unresolved.append(f"MISSING_DOC {path.relative_to(ROOT)}")
            continue
        text = path.read_text(encoding="utf-8")
        for row in table_rows(text):
            status = row_status(row)
            if status:
                label = row[1] if len(row) > 1 else ""
                unresolved.append(f"{status} {path.relative_to(ROOT)} {row[0]} {label}")

    for path in STALE_COMMIT_DOCS:
        text = path.read_text(encoding="utf-8") if path.exists() else ""
        match = re.search(r"tested_commit:\s*`([^`]+)`", text)
        if match and match.group(1) != head:
            stale.append(
                f"STALE_COMMIT {path.relative_to(ROOT)} tested_commit={match.group(1)} head={head}"
            )

    worker_ok, worker_output = run_worker_health()
    if not worker_ok:
        unresolved.append("FAIL docs/qa/LiveProviderQAMatrix.md WORKER-002 production /health contract")

    print("Full product defect audit")
    print(f"HEAD {head}")
    print("\nUnresolved rows:")
    if unresolved:
        for item in unresolved:
            print(f"- {item}")
    else:
        print("- none")

    print("\nStale evidence:")
    if stale:
        for item in stale:
            print(f"- {item}")
    else:
        print("- none")

    if worker_output:
        print("\nWorker production health:")
        print(worker_output)

    if stale:
        print("\nNOTE: stale evidence is expected until manual QA is rerun on current HEAD.")
    if unresolved or stale:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
