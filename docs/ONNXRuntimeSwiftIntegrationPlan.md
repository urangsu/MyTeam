# ONNX Runtime Swift Integration Plan

## Round 248TTS-A: Skeleton Architecture

### Overview

Supertonic3 ONNX Runtime integration requires a platform-specific boundary layer to handle:
- Cloud environment (no runtime available)
- Mac local environment (SPM `onnxruntime-swift-package-manager` available)
- Model file discovery and validation
- Session lifecycle management

### Architecture

```
Supertonic3TTSProvider
  ├─ Config enabled/preset validation
  ├─ Model locator (file discovery)
  ├─ Inference pipeline (skeleton, Cloud throws missingRuntime)
  │   ├─ ONNXRuntimeAdapter (protocol abstraction)
  │   ├─ Text encoder stage (placeholder)
  │   ├─ Duration predictor stage (placeholder)
  │   ├─ Vector estimator stage (placeholder)
  │   └─ Vocoder stage (placeholder)
  └─ TTSOutput result
```

### Cloud (Round 248TTS-A)

**ONNXRuntimeAdapter.swift:**
- `ONNXRuntimeAvailability` enum: `.unavailable`
- `ONNXRuntimeSessionProtocol`: Type-safe session representation
- `ONNXRuntimeUnavailableAdapter`: Default implementation (throws missingRuntime)

**Supertonic3InferencePipeline.swift:**
- Actor-based concurrency boundary
- `prepare(modelDirectory)`: Validates manifest, loads models (throws in Cloud)
- `synthesize()`: Returns prepared pipeline or throws missingRuntime
- No model file downloads
- No fake audio generation
- Comments document 4-stage inference flow

**Supertonic3TensorTypes.swift:**
- `Supertonic3TensorInputs`: Text tokens + language + voice preset
- `Supertonic3TensorOutputs`: Float values + shape + sample rate
- `Supertonic3AudioBuffer`: Normalized audio samples

### Mac Local (Round 249TTS+)

**Plan:**

1. **SPM Dependency (Package.swift):**
   ```swift
   .package(
       url: "https://github.com/microsoft/onnxruntime-swift-package-manager",
       from: "1.16.0"
   )
   ```

2. **ONNXRuntimeAdapter Implementation:**
   - Create `ONNXRuntimeLiveAdapter: ONNXRuntimeAdapterProtocol`
   - `availability()` → checks OrtEnvironment availability
   - `loadSession(modelURL:name:)` → returns actual OrtSession
   - `run(session:inputs:)` → invokes inference

3. **Inference Pipeline Stages:**
   - Text normalization (Unicode, punctuation)
   - Tokenization (via pre-trained tokenizer model)
   - Text encoder → embedding vectors
   - Duration predictor → phoneme durations
   - Vector estimator → acoustic features
   - Vocoder → 44.1kHz PCM waveform

4. **Sample Rate Conversion:**
   - Vocoder outputs 44.1kHz (Supertonic3 default)
   - Convert to 24kHz for AudioPlaybackService
   - Use AVAudioEngine or vDSP resampling

5. **Error Handling:**
   - Missing models → missingModel
   - ONNX Runtime errors → inferenceFailure
   - Audio conversion errors → audioConversionFailure

### Key Constraints

- **No Apple TTS fallback** — If Supertonic3 unavailable, stay silent
- **No auto-download** — Users manually place models
- **No fake success** — Never return dummy audio
- **Model manifest** — Candidate filenames allow distribution flexibility
- **Redacted paths** — Never expose full paths in user-facing UI
- **Sendable types** — All tensor types conform to Sendable for actor isolation

### Testing Plan (Future)

**Unit (Swift):**
- Mock ONNXRuntimeAdapter for pipeline testing
- Tensor type round-trip serialization
- Model file locator with synthetic directory structures

**Integration (Mac local):**
- Load actual ONNX models
- Run inference on sample text ("안녕")
- Validate tensor shapes match model signatures
- Convert output WAV and verify sample rate

**Audio QA (Manual):**
- Playback synthesized speech via AudioPlaybackService
- Verify voice quality/naturalness
- Test all 10 voice presets (M1-M5, F1-F5)
- Test language switching (Korean, English, Japanese)

### License Compliance

- **Supertonic3:** MIT license (commercial OK)
- **ONNX Runtime:** MIT license (commercial OK)
- **Models:** OpenRAIL-M (no restrictions for inference)

All licenses compatible with MyTeam App Store distribution.
