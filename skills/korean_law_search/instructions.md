# Korean Law Search Reference Skill

This package is a reference contract for rebuilding the useful korean-law-mcp statute lookup behavior as a MyTeam-native `directREST` skill. It is not auto-loaded, not user-visible, and not legal advice.

## Scope

- Search Korean statutes.
- Look up statute articles.
- Return official source metadata.

Out of scope for P0:

- Case law.
- Administrative rules.
- Interpretation examples.
- Point-in-time comparison.
- Impact graphs.

## Credential

Use provider credential `ExternalProvider.koreanLaw` with field `lawOC`. The runtime must store this credential through `SecureCredentialStore` and Keychain.

## Source Policy

Every result must include:

- Law name.
- Article.
- Effective date.
- Official source URL.
- Verification status.
- Legal disclaimer.

Do not mark a result `verified` unless official source data confirms the law, article, and effective date. Missing source metadata must be `failed`.

## Legal Safety

Do not present output as attorney advice. When a user action may have legal consequence, show the result as research support and advise consulting a qualified professional.
