# Artifact Reopen Manual QA

This document verifies that natural work results persist as app-internal artifacts and can be reopened without relying only on external Markdown files.

## Evidence Metadata

- tested_commit: `837276699a11268112a09c78bc1bb60bb954c781`
- tested_build: `not run for manual QA in this pass`
- tested_at: `2026-07-06 00:08:59 KST`
- tester: `pending manual QA`
- profile: `Debug and Release both required`
- configuration: `pending manual QA`
- architecture: `pending manual QA`
- xcode_version: `pending manual QA`
- artifact_sha256: `pending manual QA`

| Case ID | Scenario | Input / Action | Expected result | Forbidden result | Actual result | PASS / FAIL / BLOCKED | Evidence | Notes |
|---|---|---|---|---|---|---|---|---|
| ART-001 | Composite artifact creation | Run NW-001 or NW-004 | Exactly one composite artifact is created for the natural work result; individual tool artifacts do not proliferate | Multiple unrelated tool artifacts for one user request | Not run in this pass | BLOCKED | Pending natural-work runtime QA | Reason: depends on NW-001 or NW-004 runtime. Next: run a company briefing and inspect artifact count. |
| ART-002 | Reopen from recent execution | Click an artifact-backed item in ToolExecutionLogView/recent results | Opens app-internal WorkArtifactDetailView | Only opens an external Markdown file or Finder | Not run in this pass | BLOCKED | Pending artifact UI QA | Reason: requires generated artifact. Next: create artifact and click recent item. |
| ART-003 | ArtifactID-only detail button | Inspect item with artifactID but no artifactFilename | Detail button is visible and opens body | No detail action because filename is absent | Not run in this pass | BLOCKED | Pending artifact fixture/runtime QA | Reason: requires artifactID-only entry. Next: create or inspect such log entry. |
| ART-004 | Long body safety | Open a long artifact | App stays responsive; preview/truncation is clear if applied | UI freeze or unbounded rendering with no indication | Not run in this pass | BLOCKED | Pending long-artifact QA | Reason: requires long artifact. Next: generate long document artifact and reopen. |
| ART-005 | Quit while saving artifact | Trigger composite artifact generation and quit while save/register is in progress | App terminates safely; next launch has no corrupted artifact entry or explains recovery | Quit hangs or leaves an unreadable recent artifact that looks complete | Not run in this pass | BLOCKED | Pending termination/artifact QA | Reason: requires runtime timing test. |
| ART-006 | Index entry exists but file missing | Create or simulate recent artifact index entry with missing file | Detail view shows missing artifact recovery state, not fake content | Blank success, Finder-only failure, crash | Not run in this pass | BLOCKED | Pending artifact integrity fixture | Reason: requires controlled fixture or runtime corruption simulation. |
| ART-007 | File exists but index missing | Place artifact file without recent index entry | App does not show a broken recent item; recovery/import path is explicit if offered | Phantom recent item or crash | Not run in this pass | BLOCKED | Pending artifact integrity fixture | Reason: requires controlled workspace fixture. |
| ART-008 | Content hash mismatch | Modify artifact file after index registration | Detail view flags mismatch or revalidates; does not claim verified unchanged content | Stale hash ignored while showing verified-looking artifact | Not run in this pass | BLOCKED | Pending hash mismatch fixture | Reason: requires artifact file mutation fixture. |
| ART-009 | Concurrent artifact saves | Complete two natural work artifacts concurrently | Both artifacts keep distinct IDs, room IDs, hashes, and recent entries | Last writer wins, duplicate IDs, wrong room assignment | Not run in this pass | BLOCKED | Pending concurrency QA | Reason: requires concurrent natural work runtime. |

## Completion Rule

ART-001 through ART-009 must be PASS before artifact reopen can support a Release Candidate recommendation.
