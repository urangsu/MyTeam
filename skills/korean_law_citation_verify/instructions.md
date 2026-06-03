# Korean Law Citation Verify Reference Skill

This package is a reference contract for rebuilding korean-law-mcp citation verification as a MyTeam-native `directREST` skill. It is not auto-loaded, not user-visible, and not legal advice.

## Scope

- Verify whether a Korean legal citation exists in official source data.
- Check law name, article, paragraph, item, and effective date when provided.
- Return mismatch details when official source data does not match the citation.

## Status Rules

- `verified`: Official source confirms the cited law text and all requested citation parts.
- `partial`: Official source is reachable, but the requested citation is ambiguous or incomplete.
- `failed`: The cited law, article, paragraph, item, effective date, or official source cannot be verified.

Citation mismatch and citation-not-found outcomes must be `failed`, not a soft success.

## Credential

Use provider credential `ExternalProvider.koreanLaw` with field `lawOC`. The runtime must store this credential through `SecureCredentialStore` and Keychain.

## Legal Safety

Do not turn citation verification into legal advice. The skill verifies whether text and citations exist; it does not decide legal strategy, compliance outcome, or user obligations.
