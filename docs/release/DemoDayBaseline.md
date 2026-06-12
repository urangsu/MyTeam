# Demo Day Baseline

Date: 2026-06-11

## Baseline

- Branch: `main`
- Pre-sprint commit SHA: `9506156f20600517fb11c6908d171c64cfaa9070`
- Product direction: functional macOS work assistant with Tool Registry based read-only/draft-first execution.
- Main TTS: Supertonic3 only.
- BubbleSpeech: Supertonic3 generated character voice effect layer.
- App Store model source: bundled `Resources/Supertonic3`.
- Developer model source: external cache allowed only in Developer profile.

## Validators Kept

- `scripts/validate_release_checklist.py`
- `scripts/validate_skill_packages.py`
- `scripts/validate_app_store_profile.py`
- `scripts/validate_supertonic3_bundle.py`
- `scripts/validate_myteam_release.py`

## Tool Surface

- `briefing.today`
- `news.search`
- `dart.disclosures.search`
- `weather.current`
- `law.search`
- `calendar.events.today`
- `spreadsheet.googleSheets.read`
- `document.meetingMinutes`
- `document.rewrite`
- `spreadsheet.postprocess`
- `voice.supertonic.preview`
- `voice.bubbleSpeech.preview`

## Remaining Risks

- Google Calendar and Google Sheets still need live OAuth QA with real accounts.
- Public API tools need valid-key QA for DART, Naver News, KMA, and Korean Law.
- Supertonic3 App Store gate remains blocked until license, redistribution, and commercial product approval are explicitly turned on.
- Manual audio QA remains required for Supertonic3 and BubbleSpeech.
- App Store sandbox runtime QA remains separate from local Debug/Release build success.
