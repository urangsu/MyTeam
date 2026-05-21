# TTS Provider Policy

**Date:** Round 266A-275Z  
**Status:** Active Governance Policy  
**Scope:** Text-to-Speech provider selection and gating

## Overview

The app supports multiple TTS providers with strict scope gating:

| Provider | Status | Scope | Enabled By Default |
|----------|--------|-------|-------------------|
| **Qwen3MLX** | ✅ Stable | Production | NO (DevLab gate only) |
| **Supertonic3** | 🧪 Experimental | Dev Lab only | NO (UserDefaults gate) |
| **Silent** (nil) | ✅ Stable | All users | YES (default) |

**Policy:** No TTS provider is enabled by default. Users must explicitly opt-in via UserDefaults or internal developer flags.

## Provider Selection (TTSRoutingPolicy.selectedProvider)

```swift
func selectedProvider() -> TTSProvider? {
    // Priority: Supertonic3 > Qwen3MLX > nil (silent)
    
    // 1. Supertonic3 (experimental, dev lab gate)
    if Supertonic3TTSConfig.isEnabled && isModelAvailable(.supertonic3) {
        return .supertonic3
    }
    
    // 2. Qwen3MLX (stable but dev lab gate)
    if isQwen3MLXEnabled() && isModelAvailable(.qwen3MLX) {
        return .qwen3MLX
    }
    
    // 3. Default: silent (nil)
    return nil
}
```

**Guarantee:** At least one of the following is true:
1. No TTS is active (returns `nil`)
2. User explicitly enabled TTS via developer settings
3. Build is in development/testing mode with internal gates set

## Supertonic3 (Experimental, Dev Lab Gated)

**File:** `MyTeam/Supertonic3TTSConfig.swift`

**Configuration:**
```swift
struct Supertonic3TTSConfig {
    static var isEnabled: Bool {
        get {
            // Read from UserDefaults, default false
            UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "supertonic3ExperimentalEnabled")
        }
    }
}
```

**Enforcement:**
- `isEnabled` defaults to `false` (no hardcoded `true`)
- Only reads from `UserDefaults.standard`
- No environment variable overrides
- No compile-time conditionals like `#if DEBUG`

**When Used:**
- Only when user explicitly sets `supertonic3ExperimentalEnabled = true` in UserDefaults
- Only in Dev Lab or testing scenarios
- Never in production release builds

**Validation:** 
```swift
assert(Supertonic3TTSConfig.isEnabled == false) // Default
assert(UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled") == false)
```

## Qwen3MLX (Stable, Dev Lab Gated)

**File:** `MyTeam/TTSLabView.swift` or relevant TTS routing logic

**Enablement:**
```swift
func isQwen3MLXEnabled() -> Bool {
    // Only true if both internal dev lab gates are set
    let hasQwen3Gate = UserDefaults.standard.bool(forKey: "qwen3MLXTTSEnabled")
    let hasDevLabMode = UserDefaults.standard.bool(forKey: "devLabMode")
    return hasQwen3Gate && hasDevLabMode
}
```

**Enforcement:**
- Both gates must be explicitly `true` to enable
- Default behavior: both are `false`
- No default enablement in release builds

**When Used:**
- Internal testing/dev lab scenarios only
- User must explicitly enable in developer settings
- Never automatically enabled based on build variant

## Silent Mode (Default)

**File:** `MyTeam/TTSRoutingPolicy.swift`

**Behavior:**
```swift
func synthesizeAndSpeak(_ text: String) -> Void {
    guard let provider = selectedProvider() else {
        // Silent mode: do nothing
        return
    }
    // ... speak using selected provider
}
```

**Default State:**
- `selectedProvider()` returns `nil`
- `synthesizeAndSpeak(_:)` does nothing (no audio output)
- User hears silence by default
- Matches user requirement: "No Apple TTS, silence by default"

## Validation Gates

### 1. ToolContractValidator.validateTTSDefaultSilentPolicy()

**Purpose:** Confirm no TTS provider is enabled by default in shipping builds.

**Enforcement:**
```swift
assert(Supertonic3TTSConfig.isEnabled == false)
assert(!isQwen3MLXEnabled()) // Both gates must be false
```

**Failure Mode:** Build fails if either provider is hardcoded enabled.

### 2. RuntimeDiagnosticsService.ttsDefaultProviderIsNilOrExperimental

**Check:** Default provider selection returns `nil` or experimental-only.

```swift
let defaultProvider = TTSRoutingPolicy.selectedProvider()
assert(defaultProvider == nil || 
       defaultProvider == .supertonic3) // Experimental
```

**Failure Mode:** If production provider is selected by default, diagnostics flag as unsafe.

### 3. RuntimeDiagnosticsService.supertonic3StrictlyDevLabGated

**Check:** Supertonic3 only enabled via UserDefaults, not compile-time constants.

```swift
let isSupertonic3UserGated = 
  Supertonic3TTSConfig.isEnabled == 
  UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled")

assert(isSupertonic3UserGated)
```

**Failure Mode:** If Supertonic3 has hardcoded `true` or compile-time gate, flag as policy violation.

## Code Patterns (Safe)

### ✅ Safe: UserDefaults-based gate

```swift
struct Supertonic3TTSConfig {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "supertonic3ExperimentalEnabled") // Defaults false
    }
}
```

### ✅ Safe: Explicit false default

```swift
func selectedProvider() -> TTSProvider? {
    if Supertonic3TTSConfig.isEnabled { // Must check runtime state
        return .supertonic3
    }
    return nil // Safe: silent by default
}
```

### ✅ Safe: Multiple gates required

```swift
func isQwen3MLXEnabled() -> Bool {
    let gate1 = UserDefaults.standard.bool(forKey: "qwen3MLXEnabled")
    let gate2 = UserDefaults.standard.bool(forKey: "devLabMode")
    return gate1 && gate2 // Both required
}
```

## Code Patterns (Unsafe — Violations)

### ❌ Unsafe: Hardcoded true

```swift
struct Supertonic3TTSConfig {
    static var isEnabled: Bool { true } // VIOLATION: always enabled
}
```

**Fix:** Use `UserDefaults.standard.bool(...)` with false default.

### ❌ Unsafe: Compile-time condition as default

```swift
func selectedProvider() -> TTSProvider? {
    #if DEBUG
        return .supertonic3 // VIOLATION: enabled in debug builds
    #else
        return nil
    #endif
}
```

**Fix:** Use runtime UserDefaults gates, not compile-time conditionals.

### ❌ Unsafe: Single gate insufficient

```swift
func isQwen3MLXEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: "qwen3MLXEnabled") // Only one gate
}
```

**Fix:** Require both `qwen3MLXEnabled` AND `devLabMode` flags.

### ❌ Unsafe: No explicit default

```swift
struct Supertonic3TTSConfig {
    static var isEnabled: Bool {
        UserDefaults.standard.string(forKey: "supertonic3State") == "on" // Unsafe parsing
    }
}
```

**Fix:** Use `.bool(...)` which defaults false, not string parsing.

## Future Changes

### Allowed
- ✅ Add new experimental providers (with UserDefaults gates)
- ✅ Promote Qwen3MLX from dev lab to stable (add shipping gate)
- ✅ Add localization/language selection to TTS
- ✅ Allow user opt-in via settings UI

### Restricted (Require Governance Review)
- ❌ Enable any TTS provider by default (must stay silent)
- ❌ Remove UserDefaults gates (must keep runtime control)
- ❌ Hardcode `true` for any provider
- ❌ Use compile-time conditionals for shipping provider selection
- ❌ Add environment variable overrides for production builds

## Testing & Verification

### Unit Test: Default is Silent

```swift
func testDefaultTTSProviderIsSilent() {
    UserDefaults.standard.removeObject(forKey: "supertonic3ExperimentalEnabled")
    UserDefaults.standard.removeObject(forKey: "qwen3MLXTTSEnabled")
    UserDefaults.standard.removeObject(forKey: "devLabMode")
    
    let provider = TTSRoutingPolicy.selectedProvider()
    XCTAssertNil(provider, "Default provider must be nil (silent)")
}
```

### Unit Test: Supertonic3 Gate Works

```swift
func testSupertonic3RequiresExplicitEnable() {
    Supertonic3TTSConfig.isEnabled = true
    let provider = TTSRoutingPolicy.selectedProvider()
    XCTAssertEqual(provider, .supertonic3, "Should select Supertonic3 when enabled")
    
    Supertonic3TTSConfig.isEnabled = false
    let providerDisabled = TTSRoutingPolicy.selectedProvider()
    XCTAssertNil(providerDisabled, "Should revert to silent when disabled")
}
```

### Manual Test: Verify No Default Audio

1. Fresh app install (all UserDefaults cleared)
2. Open app, navigate to chat
3. Trigger any speech synthesis trigger (if exposed in UI)
4. **Expected:** No audio output (silent mode)
5. **Failure:** Any audio heard without explicit user opt-in

### Manual Test: Verify Qwen3 Gate Requires Both Flags

1. Set only `qwen3MLXTTSEnabled = true` in UserDefaults
2. Trigger TTS
3. **Expected:** Silent (both gates required)
4. Set also `devLabMode = true`
5. **Expected:** TTS audio (Qwen3 now enabled)

## Compliance Checklist

- [ ] `Supertonic3TTSConfig.isEnabled` reads from UserDefaults, defaults false
- [ ] No hardcoded `true` for any TTS provider
- [ ] `TTSRoutingPolicy.selectedProvider()` returns `nil` by default
- [ ] Qwen3MLX requires both `qwen3MLXTTSEnabled` AND `devLabMode`
- [ ] ToolContractValidator includes `validateTTSDefaultSilentPolicy()`
- [ ] RuntimeDiagnosticsService includes `ttsDefaultProviderIsNilOrExperimental`
- [ ] RuntimeDiagnosticsService includes `supertonic3StrictlyDevLabGated`
- [ ] Unit tests confirm default provider is `nil`
- [ ] No `#if DEBUG` conditionals for TTS provider selection
- [ ] Code review confirms no compile-time TTS defaults
