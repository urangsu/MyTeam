# External Skill And MCP Intake Checklist

Use this checklist before copying, adapting, or referencing any external skill, MCP server, CLI, or API wrapper. The goal is to convert outside repos into MyTeam Skill Package contracts instead of pasting code into runtime.

## Intake Questions

- What is the original repo execution model: REST, MCP, CLI, local library, browser automation, or hosted proxy?
- What authentication is required?
- Can the feature work with user BYOK credentials?
- Does it require a MyTeam server/proxy?
- Is it allowed and practical in an App Store build?
- Does every result include official or inspectable source evidence?
- Are failure modes explicit and user-safe?
- Are cache, retry, timeout, or rate limit policies required?
- Does it send personal, sensitive, legal, financial, or workspace data outside the app?
- Can the result be converted into a MyTeam card or artifact without pretending it is verified?

## Classification

- `localSwift`: Safe local implementation inside the app.
- `directREST`: Direct REST call with BYOK credentials and validator.
- `myTeamProxy`: MyTeam-operated proxy; requires server policy and quota contract.
- `externalMCP`: External MCP endpoint or server; reference only until runtime policy exists.
- `disabled`: Known package idea that is intentionally unavailable.

## Reference Cases

### NomaDamas/k-skill

- Repo: `https://github.com/NomaDamas/k-skill`
- Observed shape: Korean life skill collection with agent skill packaging and hosted/proxy ideas.
- MyTeam intake posture: Do not copy runtime code. Convert individual capabilities into MyTeam `skill.json` contracts.
- First reference package: `skills/naver_news_search/skill.json`.
- Risk notes: Hosted fallback or proxy wording must not become "default lookup available" unless MyTeam owns and validates the proxy.

### chrisryugj/korean-law-mcp

- Repo: `https://github.com/chrisryugj/korean-law-mcp`
- Observed shape: Korean law MCP/CLI/remote endpoint over National Law Information Center APIs.
- MyTeam intake posture: Do not bundle the Node MCP server directly into App Store runtime. Reconstruct the useful capabilities as MyTeam `directREST` skill packages first, then consider `externalMCP` as an optional later path for power users.
- First reference packages:
  - `skills/korean_law_search/skill.json`
  - `skills/korean_law_citation_verify/skill.json`
- Risk notes: Legal output must not read as attorney advice. Source, statute name, article, effective date, and citation verification status must be visible.

## Korean Law Rebuild Posture

MyTeam should actively rebuild the useful korean-law-mcp capability in app-native form. The release-safe path is not to bundle the external Node MCP server into the App Store runtime, but to turn the capability into MyTeam-owned skill packages and Swift connectors.

Preferred sequence:

- P0 reference skill surface:
  - law search
  - article lookup
  - citation verification
- P1 later surface:
  - case law
  - administrative rules
  - interpretation examples
- P2 later surface:
  - point-in-time comparison
  - impact graph
- Add `ExternalProvider.koreanLaw` with required credential `lawOC`.
- Store `lawOC` only through `SecureCredentialStore` and the Keychain path.
- Build a Swift `directREST` connector such as `KoreanLawDirectConnector.swift` against official law APIs.
- Render the result through a `LegalResearchCard`-style contract that always shows statute name, article, effective date, official source URL, and verification status.
- Treat citation mismatch or missing source as `failed`, not as verified or connected.
- Forbid source-free legal advice and any wording that reads like attorney advice.
- Keep `externalMCP` available only as an optional later path for power-user or direct-download modes after App Store review, sandbox, endpoint trust, logging, and privacy review are complete.

## App Store Boundary

Do not bundle Node MCP servers, external CLI runtimes, or hosted MCP calls into App Store user-facing runtime without a separate release review. External MCP packages stay non-auto-loaded and non-user-visible until approved.

## Acceptance Gate

An external skill can move past reference status only when:

- `scripts/validate_skill_packages.py` passes.
- Credentials are either matched to `ProviderCredential` or documented as external.
- Source policy blocks source-free verified claims.
- UI contract has failed/partial states.
- Runtime execution has a real validator.
- Manual/live test evidence is recorded.
