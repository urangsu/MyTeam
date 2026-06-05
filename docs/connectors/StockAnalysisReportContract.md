# Stock Analysis Report Contract

Status: P1 contract, runtime guard reference.

MyTeam may help users organize stock questions, but it must not invent market data, technical indicators, or reasons for price movement. A stock report is allowed only when every factual claim is backed by a concrete source collected in the current run or supplied by the user.

## Allowed Without Live Sources

- User question normalization.
- Checklist of sources to review.
- Risk-factor categories.
- A statement that MyTeam cannot verify current price or cause yet.
- User-provided article, disclosure, or PDF summarization when the source is attached.

## Requires Quote Source

These fields require a concrete quote source in the current run:

- Current price.
- Price change and percentage change.
- Trading volume.
- Market cap.
- 52-week high or low.
- Currency and market session state.

If `AgentWindowManager.SourceType.quote` is missing, the report must not show current price values.

## Requires Calculation Engine

These fields require both source OHLCV data and a local calculation engine with documented formulas:

- RSI.
- MACD.
- Bollinger Bands.
- Moving average crossovers.
- Volatility bands.
- Any "overbought", "oversold", "breakout", or "support/resistance" label.

Until that engine exists, these labels must not appear as computed facts. They may only appear in a checklist such as "RSI requires historical price data and a calculation engine."

## Requires Narrative Sources

Cause or reason analysis requires at least one narrative external source:

- News article.
- DART/KIND disclosure.
- Company filing.
- Official company release.
- Market index source for broad-market context.

If narrative sources are missing, MyTeam may say: "시세는 확인했지만 뉴스나 공시 근거가 부족해 원인을 단정하지 않았습니다."

## Verification Labels

- `verified`: quote source, narrative source, and market context source are all present when the report makes price-move claims.
- `partially_verified`: some concrete sources exist, but cause or market context is incomplete.
- `quote_only`: quote exists but cause sources are missing.
- `connector_unavailable`: required quote source is missing.

No report may use `verified` for stock movement causes without source-backed quote and narrative evidence.

## UI Contract

The stock card may render:

- Source list.
- Known quote fields only when quote source exists.
- Evidence-backed news/disclosure summary.
- "Unknown / not verified" rows for missing data.
- Next actions for adding sources.

The stock card must not render:

- Fake current price.
- Fake RSI, MACD, Bollinger, or technical labels.
- Buy/sell recommendation.
- Profit guarantee.
- Cause statement without source evidence.

## Runtime Hooks

Current runtime guard reference:

- `StockEvidenceCollector` gathers quote, news, disclosure, and market context.
- `KSkillRunEngine.verificationStatus` blocks verified stock output unless quote and narrative evidence are present.
- `ChainOrchestrator.stockVerificationFailureDetail` keeps cause generation blocked when source categories are missing.

Future technical indicator implementation must add tests that prove missing OHLCV data or missing formula engine prevents indicator display.
