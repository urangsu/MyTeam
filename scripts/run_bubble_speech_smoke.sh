#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp /tmp/myteam_bubble_speech_smoke_XXXXXX.swift)"
trap 'rm -f "$TMP"' EXIT

{
  printf 'import Foundation\n\n'
  awk 'NR > 1 { print }' "$ROOT/MyTeam/KoreanSyllableDecomposer.swift"
  printf '\n'
  awk 'NR > 1 { print }' "$ROOT/MyTeam/BubbleSpeechSynthesizer.swift"
  printf '\n'
  awk 'NR > 2 { print }' "$ROOT/scripts/smoke_bubble_speech.swift"
} > "$TMP"

swift "$TMP"
