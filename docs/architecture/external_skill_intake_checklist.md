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
- MyTeam intake posture: Keep as `externalMCP` reference until App Store runtime policy, endpoint trust, credential storage, and citation verification are implemented.
- First reference packages:
  - `skills/korean_law_search/skill.json`
  - `skills/korean_law_citation_verify/skill.json`
- Risk notes: Legal output must not read as attorney advice. Source, statute name, article, effective date, and citation verification status must be visible.

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
