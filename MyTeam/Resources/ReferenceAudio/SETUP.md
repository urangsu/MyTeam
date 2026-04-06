# ReferenceAudio Setup

## 필요한 파일:
각 캐릭터별로 WAV 파일이 필요합니다:
- 레오_reference.wav
- 루나_reference.wav
- 치코_reference.wav
- 렉스_reference.wav
- 케이_reference.wav
- 래키_reference.wav
- 모코_reference.wav
- 핀_reference.wav
- 폴라_reference.wav
- 몽몽_reference.wav
- 올리버_reference.wav

## 설정 방법:

### 옵션 1: HuggingFace에서 다운로드
Chatterbox 모델 리포지토리에서 reference voice 다운로드:
https://huggingface.co/onnx-community/chatterbox-multilingual-ONNX

### 옵션 2: 자신의 음성 녹음
각 캐릭터별로 3-5초 정도의 한국어 음성을 WAV로 녹음하여 저장

### 옵션 3: 온라인 TTS로 생성
Python + TTS 라이브러리로 생성:
```python
from TTS.api import TTS
tts = TTS(model_name="tts_models/ko/glow-tts/glow-tts-ko")
tts.tts_to_file("안녕하세요, 저는 루나입니다.", file_path="루나_reference.wav")
```

## 참고:
- 현재 fallback: Apple TTS / AnimalTTSManager 사용
- OnDeviceTTSManager는 reference voice를 찾을 수 없으면 fallback TTS 사용
