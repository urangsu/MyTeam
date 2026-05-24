# Conversation Reliability Policy

## Purpose

MyTeam conversations must not fail because a configured provider has no key, a single model name is unavailable, or a display path stores TTS-only text instead of the LLM response.

## Rules

- `AIService.getResponseStream` must select from providers that actually have API keys.
- Recoverable provider failures such as missing keys, 401/403/404/429, and server errors should try the next available provider before surfacing an error.
- Prompt history must exclude the current user turn because AIService appends the active request separately.
- Chat display text must be the LLM response text, not a TTS-normalized chunk.
- TTS chunking may shorten or normalize text only for audio input. It must not mutate persisted chat logs.
- Room profile and room-scoped memory must be assembled before LLM calls; legacy global memory must not be the only context path.

## QA

- OpenAI-only, Claude-only, Gemini-only, and OpenRouter-only key states should produce a response when the selected provider is usable.
- Sending one message should not duplicate that message in prompt history.
- Voice mode should store full assistant text, even when TTS chunks are shortened for playback.
- Switching personal/team rooms must keep response history room-scoped.
- `/blog-source` profile context must remain room-scoped and should not leak into other rooms.
