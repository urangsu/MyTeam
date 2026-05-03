# Reference Audio Audit

> 최종 업데이트: 2026-05-02
> 기준: `POLICY.md` (4~7초, 24kHz mono, 16-bit, -20 LUFS)

---

## 현재 상태 요약

| 캐릭터 | 파일명 | 크기 | 추정 길이 | 존재 | 품질 | 메모 |
|--------|--------|------|-----------|------|------|------|
| 래키 | 래키_reference.mp3 | 210KB | ~13.4s | ✅ | ⚠️ 검토 필요 | 기준(4~7초) 초과 — 클리핑 후 사용 중 |
| 레오 | 레오_reference.mp3 | 268KB | ~17.2s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 렉스 | 렉스_reference.mp3 | 332KB | ~21.2s | ✅ | ⚠️ 검토 필요 | 기준 초과, 가장 긴 파일 |
| 루나 | 루나_reference.mp3 | 237KB | ~15.2s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 모코 | 모코_reference.mp3 | 273KB | ~17.5s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 몽몽 | 몽몽_reference.mp3 | 287KB | ~18.4s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 올리버 | 올리버_reference.mp3 | 234KB | ~15.0s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 치코 | 치코_reference.mp3 | 230KB | ~14.7s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 케이 | 케이_reference.mp3 | 250KB | ~16.0s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 폴라 | 폴라_reference.mp3 | 251KB | ~16.1s | ✅ | ⚠️ 검토 필요 | 기준 초과 |
| 핀 | 핀_reference.mp3 | 286KB | ~18.3s | ✅ | ⚠️ 검토 필요 | 기준 초과 |

---

## 현재 로드 동작

- `Qwen3TTSService.clippedReferenceAudio()` 에서 24000 * 6 = 144,000 샘플(6초)로 자동 클리핑
- 파일이 길어도 앞 6초만 사용됨 → 긴 reference가 즉시 문제는 아님
- voice clone 기본값 OFF (`MyTeam.TTS.useQwenVoiceClone` 키 필요)

---

## 필요 작업 (voice clone 재활성 전)

- [ ] 각 파일 실청: 앞 6초 구간이 깨끗한 단음 발화인지 확인
- [ ] 앞뒤 무음(silence) 확인: 1초 이상 무음이 앞에 있으면 clipping 후 실제 음성 없음
- [ ] 잡음/배경음 없는지 확인
- [ ] 가능하면 4~7초 깨끗한 단일 발화로 교체 권장
- [ ] loudness 측정: -20 LUFS 기준 (ffmpeg -filter loudnorm 사용)

---

## 파일명 → 캐릭터 매핑 (ModelCatalog.characterPolicies 기준)

| policy referenceFile | 실제 파일 |
|---------------------|-----------|
| 래키_reference.mp3 | ✅ 일치 |
| 레오_reference.mp3 | ✅ 일치 |
| 렉스_reference.mp3 | ✅ 일치 |
| 루나_reference.mp3 | ✅ 일치 |
| 모코_reference.mp3 | ✅ 일치 |
| 몽몽_reference.mp3 | ✅ 일치 |
| 올리버_reference.mp3 | ✅ 일치 |
| 치코_reference.mp3 | ✅ 일치 |
| 케이_reference.mp3 | ✅ 일치 |
| 폴라_reference.mp3 | ✅ 일치 |
| 핀_reference.mp3 | ✅ 일치 |

---

## voice clone 재개 게이트 (TASK.md P0 기준)

다음 항목을 **모두** 통과해야 voice clone 재활성 고려:

- [ ] 앱 컨테이너 캐시: 모델 파일 확인 (cold start < 15s)
- [ ] 25자 이하 합성: warm RTF < 1.0 (cold 제외)
- [ ] punctuation-only 입력 0건: "." "!" "?" 단독 합성 에러 없음
- [ ] 각 캐릭터 reference 앞 6초 실청 통과
- [ ] quality gate: 10회 이상 합성 중 fallback 0건
