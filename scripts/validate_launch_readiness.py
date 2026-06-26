#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> int:
    print("+ " + " ".join(command))
    result = subprocess.run(command, cwd=ROOT, text=True)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate MyTeam launch readiness gates.")
    parser.add_argument("--main-merge", action="store_true", help="Require manual main-merge QA evidence to be PASS.")
    parser.add_argument("--release-tag", action="store_true", help="Require release live/provider gate to be PASS or DISABLED.")
    parser.add_argument("--worker-live", action="store_true", help="Check deployed Cloudflare Worker production /health.")
    args = parser.parse_args()

    commands: list[list[str]] = [
        ["python3", "scripts/validate_release_qa_evidence.py"],
    ]
    if args.main_merge:
        commands.append(["python3", "scripts/validate_release_qa_evidence.py", "--strict"])
    if args.release_tag:
        commands.append(["python3", "scripts/validate_release_qa_evidence.py", "--release-strict"])
    if args.worker_live:
        commands.append(["python3", "scripts/validate_worker_production_health.py"])

    failures = 0
    for command in commands:
        if run(command) != 0:
            failures += 1

    if failures:
        print(f"FAIL: launch readiness validation failed ({failures} failing command(s))")
        return 1

    mode = "release-tag" if args.release_tag else "main-merge" if args.main_merge else "static"
    print(f"PASS: launch readiness validation ({mode})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
