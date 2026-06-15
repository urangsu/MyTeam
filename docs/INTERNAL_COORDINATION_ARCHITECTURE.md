# Internal Coordination Architecture

## Definition

MyTeam internal coordinators are Swift services, not separately installed local agents.

They make deterministic local decisions:

- intent routing
- prompt budgeting
- credential readiness
- permission decisions
- result formatting
- character line rendering
- typing coordination
- speech playback coordination
- audit logging

They should not call an LLM by default.

## User Installation

Users install only the MyTeam app.

App Store features must not require:

- local agent installation
- local LLM server
- MCP server
- `node` or `npx`
- Python backend
- localhost service
- external model cache path

## Anti-Pattern

Do not implement one LLM call per visible character or team member.

A user request should generally produce:

- 0 LLM calls for deterministic tool routing
- 1 LLM call for normal chat or drafts
- local distribution into cards, character bubbles, and status lines

## Local LLM

Local LLM support is an optional provider adapter, not an internal coordinator.

Developer or Direct builds may experiment with a local endpoint later. App Store builds must not depend on localhost servers, `node`/`npx`, Python backends, or external model cache paths.

Local LLM support must not be used to bypass permissions, execute tools, decide destructive actions alone, replace credential validation, or present stale facts as current.
