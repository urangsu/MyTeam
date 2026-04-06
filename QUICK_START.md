# Quick Start: Chatterbox TTS

## 🚀 Start in 3 Steps

### 1. Start the Service
```bash
cd /Users/su/Desktop/TTS맨/chatterbox
./start_tts_service.sh
```

**Expected output:**
```
🚀 Starting Chatterbox TTS service...
✅ Service is ready!
{
  "status": "ok",
  "device": "mps",
  "sample_rate": 24000
}
```

### 2. Run the App
```bash
cd /Users/su/Desktop/MyTeam/MyTeam
open MyTeam.xcodeproj
# Press ⌘R to build and run
```

### 3. Test Agent Speech
- Drag an agent window to trigger discussion
- Listen for character voice playback
- Verify emotion tone (joy/sadness/anger)

---

## ✅ What Works

✅ **Chatterbox TTS Synthesis**
- Natural Korean speech synthesis
- 23+ language support
- 10+ character voice profiles

✅ **Voice Cloning**
- Reference voice samples in `/Resources/ReferenceAudio/`
- Emotion-based voice modulation
- Zero-shot voice cloning

✅ **Emotional Speech**
- Joy: Bright, excited voice (exaggeration: 0.8)
- Sadness: Soft, somber voice (exaggeration: 0.2)
- Anger: Intense, forceful voice (exaggeration: 0.7)
- Neutral: Natural speaking tone (exaggeration: 0.5)

✅ **Auto-Startup**
- Service starts automatically on app launch
- No manual intervention required
- First use: 20-30s (model download)
- Subsequent uses: 2-5s per synthesis

---

## 🎯 How It Works

```
[MyTeam App]
    ↓
[TTSServiceManager]
Checks if Python service running
If not: starts it (background)
    ↓
[OnDeviceTTSManager]
Sends HTTP POST /synthesize
ref_voice: character_reference.mp3
text: agent response
emotion: joy|sad|angry|neutral
    ↓
[Python Service: tts_service.py]
Port 9999, localhost only
Runs Chatterbox model (PyTorch)
    ↓
[Audio Response]
24kHz WAV format
    ↓
[AVAudioPlayerNode]
Plays synthesized speech
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `tts_service.py` | Python HTTP server (port 9999) |
| `OnDeviceTTSManager.swift` | HTTP synthesis client |
| `TTSServiceManager.swift` | Service lifecycle management |
| `SpeechManager.swift` | Integration point |
| `/Resources/ReferenceAudio/` | Character voice samples |

---

## ⚙️ Troubleshooting

### Service won't start?
```bash
# Check Python version
python3 --version  # Need 3.10+

# View service logs
tail -50 /Users/su/Desktop/TTS맨/chatterbox/tts_service.log

# Manual restart
pkill -f tts_service.py
./start_tts_service.sh
```

### Port already in use?
```bash
# Kill existing process
lsof -i :9999
kill -9 <PID>

# Or use different port
TTS_PORT=9998 ./start_tts_service.sh
```

### No audio?
1. Check volume: System Settings → Sound
2. Verify service: `curl http://127.0.0.1:9999/health`
3. Check reference voices: `ls /Users/su/Desktop/MyTeam/MyTeam/Resources/ReferenceAudio/`

---

## 📊 Performance

| Task | Time |
|------|------|
| Cold start (first run) | 20-30s |
| Warm start (2nd+ run) | 2-5s |
| Audio latency | <100ms |
| Memory usage | 2-3GB |

---

## 📚 Documentation

- **Setup Guide**: `/Users/su/Desktop/MyTeam/CHATTERBOX_SETUP.md`
- **Technical Docs**: `/Users/su/Desktop/TTS맨/chatterbox/TTS_SERVICE_README.md`
- **Implementation Details**: `/Users/su/Desktop/MyTeam/IMPLEMENTATION_COMPLETE.md`

---

## ✨ Character Voices

All 11 characters supported with unique voice profiles:

- **루나**: Bright, cheerful female
- **레오**: Deep, calm male
- **치코**: Emotional, expressive female
- **렉스**: Slow, grandfatherly male
- **케이**: Neutral, balanced male
- **래키**: Energetic, enthusiastic male
- **모코**: Professional, composed male
- **핀**: Active, artistic female
- **폴라**: Energetic, business female
- **몽몽**: Warm, caring female
- **올리버**: Careful, detail-oriented male

---

## 🔧 Configuration

### Change Port
```bash
# Start with custom port
TTS_PORT=9998 ./start_tts_service.sh

# Update Swift code
# In TTSServiceManager.swift:
private let serviceURL = "http://127.0.0.1:9998"
```

### Add New Character Voice
1. Record/source character voice sample (10-30 seconds, .mp3/.wav)
2. Place in: `/Users/su/Desktop/MyTeam/MyTeam/Resources/ReferenceAudio/`
3. Filename: `{character_name}_reference.mp3`
4. Add to `CharacterVoiceConfig.allCharacters`
5. Rebuild app

### Adjust Emotion Strength
Edit `CharacterVoiceConfig.swift` → `emotionConfig()`
- Lower `exaggeration` = more subtle emotion
- Higher `cfg_weight` = more consistency with reference

---

## 🎬 Demo

```bash
# Test synthesis with Korean text
cd /Users/su/Desktop/TTS맨/chatterbox
.venv/bin/python3 test_http_synthesis.py
# Generates /tmp/test_synthesis.wav

# Play the audio
afplay /tmp/test_synthesis.wav
```

---

## 📝 Summary

You now have a complete **voice synthesis system** for your agents:

✅ **Backend**: Chatterbox Python service (HTTP API)
✅ **Frontend**: Swift integration with auto-startup
✅ **Voices**: 11 character profiles with emotion control
✅ **Quality**: Natural-sounding multilingual speech
✅ **Performance**: 2-5 seconds per request
✅ **Documentation**: Setup guides + technical reference

**Next**: Start the service and test with your app!

```bash
./start_tts_service.sh
# Then run MyTeam.app and trigger agent speech
```

---

**Need help?** Check `/Users/su/Desktop/MyTeam/CHATTERBOX_SETUP.md` for detailed troubleshooting.
