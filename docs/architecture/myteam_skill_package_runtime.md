# MyTeam Skill Package Runtime

This document defines the contract for MyTeam skill packages. It is a design and validation standard only. Packages described here are not automatically loaded into the app runtime until a later implementation explicitly wires them in.

## Goals

- Move Korean life and office capabilities from scattered code paths into package contracts.
- Keep `ChainOrchestrator`, `KSkillAssistRuntime`, and current skill routing unchanged for now.
- Make each skill package describe its credentials, execution mode, input/output schema, failure modes, source policy, UI card contract, artifacts, and tests.
- Prevent fake success by requiring explicit sources, credentials, and validation before any package can be user-visible.

## Directory Structure

```text
skills/
  <skill_id>/
    skill.json
    instructions.md
    examples/
      basic.json
    tests/
      validator_cases.json
```

Only `skill.json` is mandatory at intake time. `instructions.md`, examples, and validator cases are strongly recommended for any skill intended to move beyond reference status.

## `skill.json` Contract

Required fields:

- `id`: Stable package id. Use lowercase snake case.
- `version`: Package contract version.
- `kind`: One of `localSwift`, `directREST`, `myTeamProxy`, `externalMCP`, `disabled`.
- `display_name`: User-facing name, not a status claim.
- `description`: What the package does and what it does not do.
- `source_repo`: Origin repo or `"internal"`.
- `runtime`: Must include `auto_load` and `user_visible_enabled`. Reference packages must set both to `false`.
- `execution_modes`: One or more execution modes such as `byokDirect`, `proxyPlanned`, `externalMCP`, `directRESTLater`, or `disabled`.
- `required_credentials`: Credential contract. Must match MyTeam provider schema or be clearly marked external.
- `input_schema`: JSON-compatible input schema.
- `output_schema`: JSON-compatible output schema.
- `failure_modes`: Non-empty list of explicit failure codes and user-safe messages.
- `source_policy`: Source and verification requirements.
- `ui`: Card rendering contract.
- `rules`: Non-empty list of truth, safety, and formatting rules.

## Required Credentials

Provider credentials must match `ExternalProvider.credentialSchema` exactly.

```json
{
  "type": "provider",
  "provider": "naverNews",
  "fields": ["clientID", "clientSecret"]
}
```

External credentials are allowed only when MyTeam does not yet have a provider schema. They must not be treated as connected in the app until a real credential store and validator are implemented.

```json
{
  "type": "external",
  "id": "LAW_OC",
  "description": "National Law Information Center open API key or Korean Law MCP endpoint."
}
```

## Execution Modes

- `byokDirect`: User brings credentials; app calls the upstream API directly.
- `proxyPlanned`: UI slot only. No "default lookup available" claim until MyTeam operates a real proxy.
- `myTeamProxy`: MyTeam server/proxy owns upstream execution.
- `externalMCP`: External MCP server or endpoint. Not bundled into App Store runtime by default.
- `directRESTLater`: Possible future direct REST path.
- `disabled`: Contract exists, but package is not available.

## Source Policy

Packages that return news, law, disclosures, stocks, or current facts must include source metadata. A result can be labeled verified only when `source_policy.verified_label_requires` has been satisfied by real upstream evidence.

Source policy must define:

- Whether sources are mandatory.
- What evidence allows a verified label.
- Preferred source types or domains when relevant.
- How to handle missing, stale, or conflicting sources.

## Card Renderer Contract

The `ui` block declares the card type and rendering obligations. It does not instantiate a view.

Cards must:

- Render source links when `requires_source_links=true`.
- Show failed/partial states without implying success.
- Avoid "connected", "verified", "available", or current factual claims unless runtime validation proves them.
- Keep demo/sample data visibly labeled.

## Artifact Policy

Artifacts are optional. Packages that create artifacts must define whether the artifact is user-requested, source-backed, and safe to persist. Reference packages should default to no artifact unless there is a concrete output contract.

## Failure Modes

Every package must list failure modes. At minimum:

- Missing credentials.
- Invalid credentials.
- Provider unavailable.
- Rate limited.
- Response parse failure.
- Source missing or unverifiable.

Legal packages must include citation mismatch or citation verification failure when applicable.

## Manual And Live Test Policy

- Static validation must run on every `skills/*/skill.json`.
- Live tests require real credentials or a declared external MCP endpoint.
- Manual/live checks must remain separate from `status=done` claims until evidence is recorded.
- Runtime auto-load remains forbidden until validator, credential store, and UI truth surface are all implemented.

## Runtime Boundary

This document does not authorize:

- Loading packages into `SkillRegistry`.
- Calling MCP servers from App Store runtime.
- Showing packages as user-available.
- Replacing `ChainOrchestrator` or `KSkillAssistRuntime`.

The next runtime phase must add a separate approval gate before any package can execute.
