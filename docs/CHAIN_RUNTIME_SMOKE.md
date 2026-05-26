# Chain Runtime Smoke Suite

MyTeam chain runtime smoke suite is intentionally separated from the normal Debug/Release build.
It is a product-safety diagnostic for checking whether chain routing, source typing, fallback UX, and action-runtime guardrails still match the current runtime contract.

## Current Scenarios

1. `stock-degraded-connector`
2. `stock-no-quote-source`
3. `stock-quote-news`
4. `mail-command-only`
5. `mail-ambiguous`
6. `mail-body`
7. `document-image-no-ocr`
8. `document-pdf-with-text`
9. `action-artifact-write-fail`
10. `action-chain-run-id-missing`

## Pass Rules

- Stock cards must never become `verified` without a `quote` source.
- Stock cause analysis must never be treated as verified without `news` or `disclosure` evidence.
- `marketIndex` must be separate from `news` and `disclosure`.
- Ambiguous short mail text must show a user choice card instead of auto-summary success.
- Image/PDF attachments with no extracted text must fail or request OCR, not classify successfully from filename alone.
- Local draft actions must return `failed` if artifact persistence fails.
- Action artifact writes must require `chainRunID`.

## Entry Point

The in-app entry point is `ChainRuntimeSmokeSuite.run()`.
The diagnostics summary exposes the available case count through `RuntimeDiagnosticsService`.
