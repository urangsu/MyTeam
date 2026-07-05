# Artifact Reopen Manual QA

This document verifies that natural work results persist as app-internal artifacts and can be reopened without relying only on external Markdown files.

## Evidence Metadata

- tested_commit: `837276699a11268112a09c78bc1bb60bb954c781`
- tested_build: `not run for manual QA in this pass`
- tested_at: `2026-07-06 00:08:59 KST`
- tester: `pending manual QA`
- profile: `Debug and Release both required`

| Case ID | Scenario | Input / Action | Expected result | Forbidden result | Actual result | PASS / FAIL / BLOCKED | Evidence | Notes |
|---|---|---|---|---|---|---|---|---|
| ART-001 | Composite artifact creation | Run NW-001 or NW-004 | Exactly one composite artifact is created for the natural work result; individual tool artifacts do not proliferate | Multiple unrelated tool artifacts for one user request | Not run in this pass | BLOCKED | Pending natural-work runtime QA | Reason: depends on NW-001 or NW-004 runtime. Next: run a company briefing and inspect artifact count. |
| ART-002 | Reopen from recent execution | Click an artifact-backed item in ToolExecutionLogView/recent results | Opens app-internal WorkArtifactDetailView | Only opens an external Markdown file or Finder | Not run in this pass | BLOCKED | Pending artifact UI QA | Reason: requires generated artifact. Next: create artifact and click recent item. |
| ART-003 | ArtifactID-only detail button | Inspect item with artifactID but no artifactFilename | Detail button is visible and opens body | No detail action because filename is absent | Not run in this pass | BLOCKED | Pending artifact fixture/runtime QA | Reason: requires artifactID-only entry. Next: create or inspect such log entry. |
| ART-004 | Long body safety | Open a long artifact | App stays responsive; preview/truncation is clear if applied | UI freeze or unbounded rendering with no indication | Not run in this pass | BLOCKED | Pending long-artifact QA | Reason: requires long artifact. Next: generate long document artifact and reopen. |

## Completion Rule

ART-001 through ART-004 must be PASS before artifact reopen can support a Release Candidate recommendation.
