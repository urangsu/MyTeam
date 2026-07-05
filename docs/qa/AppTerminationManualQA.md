# App Termination Manual QA

This document records manual evidence for AppTerminationCoordinator. Static architecture checks are not a substitute for process-level quit QA.

## Evidence Metadata

- tested_commit: `837276699a11268112a09c78bc1bb60bb954c781`
- tested_build: `not run for manual QA in this pass`
- tested_at: `2026-07-06 00:08:59 KST`
- tester: `pending manual QA`
- profile: `Debug and Release both required`

| Case ID | Scenario | Input / Action | Expected result | Forbidden result | Actual result | PASS / FAIL / BLOCKED | Evidence | Notes |
|---|---|---|---|---|---|---|---|---|
| APPTERM-001 | Idle Cmd+Q | Launch MyTeam, do no work, press Cmd+Q, wait 6 seconds, run `pgrep -fl MyTeam` | App exits within 5 seconds, no process remains, no crash, no duplicate termination reply | Process remains, crash, repeated termination reply | Not run in this pass | BLOCKED | Pending manual UI run | Reason: requires interactive app launch. Next: run from Debug and Release app builds. |
| APPTERM-002 | Menu quit | Launch MyTeam, choose MyTeam > Quit, wait 6 seconds, run `pgrep -fl MyTeam` | Quit path uses `AppTerminationCoordinator.requestMenuQuit`, exits within 5 seconds | Menu path bypasses coordinator or process remains | Not run in this pass | BLOCKED | Pending manual UI run | Reason: requires menu interaction. Next: run menu quit in built app. |
| APPTERM-003 | AppleScript quit | Run `osascript -e 'tell application "MyTeam" to quit'`, wait 6 seconds, run `pgrep -fl MyTeam` | App exits within 5 seconds, no process remains | Process remains or AppleScript quit hangs | Not run in this pass | BLOCKED | Pending manual script run | Reason: app launch state not established in this pass. Next: run AppleScript against installed/built app. |
| APPTERM-004 | TTS playback quit | Start Supertonic3/BubbleSpeech playback, press Cmd+Q | Farewell/audio does not block termination; engine stop has timeout; app exits within 5 seconds | Waiting for speech to finish, infinite wait, process remains | Not run in this pass | BLOCKED | Pending audio QA | Reason: requires live TTS playback. Next: run with active speech. |
| APPTERM-005 | Tool execution quit | Start News/Law/Finance lookup, press Cmd+Q during execution | Active workflow task cancels; app exits within 5 seconds | Tool task keeps app alive indefinitely | Not run in this pass | BLOCKED | Pending live tool QA | Reason: requires app runtime lookup. Next: run during read-only tool execution. |
| APPTERM-006 | Artifact detail quit | Open ToolExecutionLogView or WorkArtifactDetailView, press Cmd+Q | Detail screen does not delay termination | Artifact/detail persistence blocks quit | Not run in this pass | BLOCKED | Pending artifact UI QA | Reason: requires runtime artifact detail surface. Next: run after opening artifact detail. |

## Static Evidence

- `python3 scripts/validate_app_termination_architecture.py`: expected to pass before this QA can be considered structurally ready.

## Completion Rule

APPTERM-001 through APPTERM-006 must be PASS before this area can support a Release Candidate recommendation. Any BLOCKED row requires a reason and next action.
