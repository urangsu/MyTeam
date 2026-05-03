# Reference Audio Policy

> 버전: 1.0 (2026-05-02)

---

## 기준

| 항목 | 기준 | 이유 |
|------|------|------|
| 길이 | 4~7초 | 짧으면 화자 특성 부족, 길면 clipping 후 무음 구간 위험 |
| 샘플레이트 | 24kHz | Qwen3TTS 내부 처리 샘플레이트와 일치 |
| 채널 | mono (1ch) | voice clone 입력 스펙 |
| 비트 깊이 | 16-bit | 표준 오디오 품질 |
| 음량 | -20 LUFS (±2) | 너무 조용하면 feature 추출 실패, 너무 크면 클리핑 |
| 앞뒤 무음 | 최소화 (<0.2s) | clipping 후 실제 발화 구간 확보 |
| 끝 처리 | fade out 0.1s | 급격한 끊김 방지 |
| 포맷 | MP3 (128kbps+) 또는 WAV | 앱 번들 크기 고려 MP3 권장 |
| 내용 | 자연스러운 단일 문장 발화 | 다양한 음소 포함 권장 |
| 잡음 | 없음 | 배경 음악/잡음은 voice clone 품질 저하 |

---

## 파일 검수 절차

```bash
# 1. 길이 확인 (ffprobe)
ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 파일.mp3

# 2. 음량 측정
ffmpeg -i 파일.mp3 -filter:a loudnorm=print_format=json -f null - 2>&1 | grep input_i

# 3. 샘플레이트/채널 확인
ffprobe -v quiet -show_entries stream=sample_rate,channels -of default=noprint_wrappers=1 파일.mp3

# 4. 정규화 (기준 미달 시)
ffmpeg -i 입력.mp3 -filter:a "loudnorm=i=-20:lra=7:tp=-1.5" -ar 24000 -ac 1 출력.mp3
```

---

## 현재 적용 상태

- `Qwen3TTSService.clippedReferenceAudio()`: 144,000 샘플(6초@24kHz)으로 앞부분 자동 클리핑
- voice clone 기본 OFF: `UserDefaults["MyTeam.TTS.useQwenVoiceClone"] = true` 시 개발 검증 모드로만 활성화
- fallback 정책: `CharacterTTSPolicy` in `ModelCatalog.swift` (maxConsecutiveFailures=3, .baseVoice)
