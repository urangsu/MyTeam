# Deployment Target Strategy

## Current Configuration

```
MACOSX_DEPLOYMENT_TARGET = 26.2
```

## Risk Assessment

### Reach Impact
- macOS 26.2 introduced mid-2026
- Current macOS user base as of 2026-05: ~40-60% on macOS 26+
- Users on macOS 25.x or earlier: cannot install

### SDK Compatibility
- Xcode 16 default: macOS 15+
- Xcode 17+ may default to macOS 26+
- App Store: accepts binaries with MACOSX_DEPLOYMENT_TARGET 15+, but requires submission review

### API Availability
- Swift 6 concurrency: macOS 13+
- MainActor: macOS 13+
- Codable + Sendable: macOS 14+
- Likely macOS 26-specific APIs: pending investigation

## Investigation Checklist

- [ ] grep #available(macOS 26)
- [ ] grep #available(macOS 25)
- [ ] check CloudKit usage (if any)
- [ ] check FileProvider usage (if any)
- [ ] check MKReverseGeocodingRequest (if used)
- [ ] assess fallback feasibility
- [ ] review Xcode 16 minimum deployment target warnings

## Decision

### Do Not Lower in Round 76A-95Z Cloud
Cloud environment is not sufficient for testing fallback code paths. Lowering without testing introduces risk.

### Revisit on Round 96A Mac Local
Before Archive/upload dry run:
1. Run investigation checks above
2. Identify all macOS 26-specific APIs
3. Evaluate fallback implementations
4. Consider lower target if feasible (e.g., macOS 15+)
5. Test fallback on macOS 25.x VM if available

### Strategy if Lowering Needed
```
Option A: Remove macOS 26-specific APIs
- Refactor to macOS 15+ compatible code
- Add #available guards for newer features

Option B: Add conditional feature flags
- macOS 26+: use new APIs
- macOS 25.x: use fallback or disabled feature

Option C: Keep macOS 26+ target
- Focus on macOS 26+ user base
- Market to early adopters
```

## Related Considerations

### App Store Submission
- Minimum deployment target for submission: check with App Store Connect
- Catalina (10.15): EOL 2024
- Big Sur (11): EOL 2023
- Current target (26.2): appropriate for 2026 release

### Build Time
- Lowering target increases build validation (more SDK compatibility checks)
- May slow xcodebuild by 10-30%

### Beta Testing
- Testers must be on macOS 26+ if target stays at 26.2
- If testing on macOS 25, must lower target first

## Action Items

- [ ] Finalize deployment target strategy on Mac local (Round 96A)
- [ ] Document any macOS 26-specific APIs discovered
- [ ] Plan fallback implementation if lowering is needed
- [ ] Update this document with findings
