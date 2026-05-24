# Round 263 Conversation Reliability Gate

## Problem

The app could appear conversationally unreliable even when room separation existed:

- A default Gemini path could fail when only another provider key was configured.
- Current user turns could be included in history and then appended again by AIService.
- Voice mode could persist TTS-normalized chunks instead of the full LLM response.
- Room-scoped memory existed but direct chat used legacy global memory context.

## Change

- Added available-key provider candidate routing inside `AIService.getResponseStream`.
- Preserved HTTP status errors for OpenAI, Claude, and OpenRouter so provider fallback can make a real decision.
- Added `ConversationMemory.promptHistory` to exclude the active user message from prompt history.
- Changed chat log writes to return a message ID and support streaming text updates.
- Split personal chat display streaming from TTS streaming so chat logs store full LLM text.
- Switched direct and team prompts to use scoped memory context.

## Manual QA

- Configure only one provider key and send a personal message.
- Send a team message and confirm the current user request is not duplicated in the prompt history.
- Turn voice mode on and confirm the visible assistant message is not capped to the TTS chunk limit.
- Switch between personal rooms and team workrooms and confirm context remains room-scoped.

## Residual Risk

Native model validation is still provider-specific and should become a dedicated registry in the next reliability round.
