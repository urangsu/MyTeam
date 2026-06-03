# Naver News Search Reference Skill

This is a reference package only. It documents how MyTeam should represent Naver News search as a skill package contract. It is not auto-loaded and must not be shown as available in the app.

## Runtime Intent

- Use Naver Search News API through direct BYOK credentials.
- Build request URLs with `URLComponents`.
- Require provider-specific body parsing before connected/verified state.
- Render source links for every news item.

## Truth Rules

- Never summarize source-free results.
- Never label a result verified from HTTP status alone.
- Never imply MyTeam provides a proxy-backed default lookup until a real MyTeam proxy exists.
