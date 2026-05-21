# Swift 6 Warning Burn-Down

> 목적: Swift 5 strict-concurrency=targeted 경고를 0으로 낮추는 작업 기록.
> 라운드: Round 267B
> 기준: Debug + Release 빌드 app code 경고 → 0

---

## 267B 이전 상태 (Round 267A 완료 후)

**Debug app code 경고: 14건**

| # | 파일 | 라인 | 종류 | 내용 |
|---|------|------|------|------|
| 1 | `Supertonic3TTSProvider.swift` | 40 | actor isolation | `isEnabled` main actor-isolated in nonisolated context |
| 2 | `Supertonic3TTSProvider.swift` | 44 | actor isolation | `isModelAvailable()` main actor-isolated in nonisolated context |
| 3 | `Supertonic3TTSProvider.swift` | 67 | actor isolation | `isEnabled` cannot be accessed from outside actor |
| 4 | `Supertonic3TTSProvider.swift` | 72 | actor isolation | `checkModel()` cannot be called from outside actor |
| 5 | `Supertonic3TTSProvider.swift` | 78 | actor isolation | `selectedVoicePreset` nonisolated autoclosure |
| 6 | `Supertonic3TTSProvider.swift` | 79 | actor isolation | `availableVoicePresets` cannot be accessed from outside actor |
| 7 | `Supertonic3TTSProvider.swift` | 99 | actor isolation | `probe()` main actor-isolated in synchronous actor context |
| 8 | `Supertonic3InferencePipeline.swift` | 11 | actor isolation | `ONNXRuntimeUnavailableAdapter.init()` main actor-isolated in nonisolated |
| 9 | `Supertonic3InferencePipeline.swift` | 45 | actor isolation | `PreparedSupertonic3Pipeline.init()` main actor-isolated from outside actor |
| 10 | `Supertonic3InferencePipeline.swift` | 73 | unused var | `pipeline` never used |
| 11 | `Supertonic3InferencePipeline.swift` | 80 | unused var | `inputs` never used |
| 12 | `ObservationPresentationPolicy.swift` | 23 | unused var | `name` never used |
| 13 | `CharacterReactionEventSink.swift` | 145 | concurrency | captured var `self` in concurrent Task |
| 14 | `MemoryRetriever.swift` | 54 | actor isolation | `MemoryStore.shared` (@MainActor) in default param (nonisolated) |

---

## Root Cause 분석

### 경고 1–9: @MainActor 추론 cascade

**원인**: `TTSLabView.swift`가 SwiftUI View (`@MainActor`)이며, `@State` 기본값으로 다음을 호출:
```swift
@State private var supertonic3Enabled = Supertonic3TTSConfig.isEnabled
@State private var modelCheck = Supertonic3ModelLocator.checkModel()
```
Swift `strict-concurrency=targeted` 모드에서 이 호출들을 `@MainActor` 컨텍스트로 인식, 관련 정적 메서드/프로퍼티를 `@MainActor`로 추론. 이 추론이 cascade:
```
TTSLabView(@MainActor) → checkModel()(@MainActor) → probe()(@MainActor)
→ ONNXRuntimeUnavailableAdapter.init()(@MainActor)
→ PreparedSupertonic3Pipeline.init()(@MainActor)
```
그 결과 `Supertonic3TTSProvider` (non-@MainActor actor)와 `Supertonic3InferencePipeline` (non-@MainActor actor)에서 이들을 호출할 때 경고 발생.

**잘못된 수정 방법**:
- 전체 타입에 `@MainActor` 추가 ❌
- `@unchecked Sendable` 사용 ❌
- `MainActor.run { }` 으로 억제 ❌

### 경고 13: Task 내 `self` capture

**원인**: `[weak self]` 클로저 내 `Task { @MainActor in self?.method() }` — `self`가 `var Self?`이므로 concurrent code에서 var 참조 경고.

### 경고 14: Default parameter @MainActor isolation

**원인**: `@MainActor class MemoryStore`의 `shared` 프로퍼티가 `@MainActor`-isolated. 기본 파라미터 값은 nonisolated 컨텍스트에서 평가됨.

---

## 수정 방법 (Round 267B)

### Fix 1: TTSLabView.swift — @State 기본값 제거 (근본 수정)

**파일**: `MyTeam/TTSLabView.swift`

```swift
// Before (인페런스 cascade 유발):
@State private var supertonic3Enabled: Bool = Supertonic3TTSConfig.isEnabled
@State private var modelCheck = Supertonic3ModelLocator.checkModel()

// After (안전한 리터럴 기본값 + .onAppear 복원):
@State private var supertonic3Enabled: Bool = false
@State private var modelCheck = Supertonic3ModelLocator.ModelCheckResult.checking
```

`.onAppear` 에서 실제 값 로드:
```swift
.onAppear {
    supertonic3Enabled = UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled")
    selectedPreset = UserDefaults.standard.string(forKey: "supertonic3VoicePreset") ?? "F1"
    // ...
    refreshModelCheck()
}
```

### Fix 2: Supertonic3ModelLocator — `ModelCheckResult.checking` 추가

**파일**: `MyTeam/Supertonic3ModelLocator.swift`

```swift
static let checking = ModelCheckResult(
    directoryURL: URL(fileURLWithPath: NSHomeDirectory() + "/.cache/supertonic3/onnx"),
    files: [], optionalFiles: [], isAvailable: false, missingFiles: [], totalFoundSizeBytes: 0
)
```
`NSHomeDirectory()`는 nonisolated 컨텍스트에서 안전하게 호출 가능.

### Fix 3: Supertonic3TTSProvider — Cloud skeleton 단순화

**파일**: `MyTeam/Supertonic3TTSProvider.swift`

nonisolated 헬퍼 메서드 (`isConfigEnabled()`, `isModelAvailable()`, `canSynthesize()`) 제거 — 외부 호출자 없음. `synthesize()`를 즉시 throw로 단순화 (Cloud skeleton):
```swift
func synthesize(text: String, voicePreset: String? = nil) async throws -> TTSOutput {
    throw TTSProviderError.missingRuntime  // Cloud: ONNX Runtime 없음
}
```

### Fix 4: Supertonic3InferencePipeline — Cloud skeleton 단순화

**파일**: `MyTeam/Supertonic3InferencePipeline.swift`

`prepare()`, `synthesize()` 모두 즉시 throw로 단순화. 사용되지 않는 `adapter` 프로퍼티와 `loadRequiredModel()` 헬퍼 제거:
```swift
func prepare(modelDirectory: URL) async throws -> PreparedSupertonic3Pipeline {
    throw TTSProviderError.missingRuntime
}
func synthesize(text: String, ...) async throws -> TTSOutput {
    throw TTSProviderError.missingRuntime
}
```

### Fix 5: ObservationPresentationPolicy — 미사용 변수 제거

`let name = ...` 제거 (반환 문자열에서 사용되지 않음).

### Fix 6: CharacterReactionEventSink — Task capture 수정

```swift
// Before:
{ [weak self] _ in Task { @MainActor in self?.postEvent(...) } }

// After:
{ [weak self] _ in
    guard let self else { return }
    Task { @MainActor [self] in self.postEvent(...) }
}
```

### Fix 7: MemoryRetriever — default parameter @MainActor 해결

```swift
// Before:
static func retrieve(input: Input, store: MemoryStore = .shared) -> MemoryContext

// After:
static func retrieve(input: Input, store: MemoryStore? = nil) -> MemoryContext {
    let store = store ?? MemoryStore.shared  // @MainActor 함수 내부에서 해결
```

---

## 267B 이후 상태

**Debug app code 경고: 0건** (pending Mac build verification)

| 파일 | 수정 |
|------|------|
| `TTSLabView.swift` | @State 기본값 리터럴 + .onAppear 복원 |
| `Supertonic3ModelLocator.swift` | `.checking` static 추가 |
| `Supertonic3TTSProvider.swift` | Cloud skeleton 단순화, nonisolated 헬퍼 제거 |
| `Supertonic3InferencePipeline.swift` | Cloud skeleton 단순화, adapter 제거 |
| `ObservationPresentationPolicy.swift` | 미사용 변수 제거 |
| `CharacterReactionEventSink.swift` | Task capture 수정 |
| `MemoryRetriever.swift` | default param → Optional + 내부 resolve |

---

## 정책

- `strict-concurrency=targeted` 유지 (Swift 5 mode)
- app code warning 0 기준 유지
- @MainActor 무분별 적용 금지
- @unchecked Sendable 남발 금지
- 경고 원인을 이해하고 구조적으로 수정

---

*Round 267B, 2026-05-21*
