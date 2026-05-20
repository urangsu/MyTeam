# Artifact Contract Policy

## Overview

The artifact contract defines how tool results must report the actual saved artifact path, not the requested filename.

## Core Principle

**ToolResult.artifactPath must always point to the actual saved artifact**, even when:
- Filename collision triggers automatic renaming (safeWritableWorkspaceURL)
- Tool creates a variant filename due to workspace constraints
- Multiple files are created and one is returned as primary

## Why This Matters

Downstream consumers of artifact results depend on accurate path reporting:
- **RecentArtifactResolver:** Looks up file by artifactPath; wrong path means wrong file retrieved
- **ArtifactCardView:** Displays artifact content; wrong path causes display failure
- **FirstResultActivation:** Opens artifact; wrong path causes FileNotFoundError
- **Summary/Reuse workflows:** Reference artifact by path; wrong path breaks continuation

### Failure Pattern (Anti-Pattern)

```swift
// WRONG: Returns input filename, ignores actual save result
let url = try safeWritableWorkspaceURL(filename: filename, context: context)
try content.write(to: url, atomically: true, encoding: .utf8)
return ToolResult(
    status: .succeeded, 
    output: "saved", 
    artifactPath: filename,  // ❌ Input, not actual
    error: nil
)
```

**Problem:** If safeWritableWorkspaceURL renames to "document-20260520-0012.md", artifactPath still claims "document.md". Later consumers look for wrong file.

## Correct Pattern

```swift
// CORRECT: Returns actual saved filename
let url = try safeWritableWorkspaceURL(filename: filename, context: context)
try content.write(to: url, atomically: true, encoding: .utf8)
let savedFilename = url.lastPathComponent
return ToolResult(
    status: .succeeded, 
    output: "\(savedFilename) saved", 
    artifactPath: savedFilename,  // ✅ Actual file on disk
    error: nil
)
```

**Correct:** artifactPath always matches the file that actually exists on disk.

## Application: WriteTextFileTool (Round 245A-P0)

**File:** `MyTeam/WriteTextFileTool.swift`

**Fix:**
```swift
let url = try safeWritableWorkspaceURL(filename: filename, context: context)
try content.write(to: url, atomically: true, encoding: .utf8)
let savedFilename = url.lastPathComponent        // Extract actual saved name
let summary = "\(savedFilename) 저장 완료 (\(content.count)자)"
return ToolResult(status: .succeeded, output: summary, artifactPath: savedFilename, error: nil)
```

## Enforcement

**ToolContractValidator.validateWriteTextFileArtifactPathPolicy()** validates:
1. WriteTextFileTool.swift exists
2. No `artifactPath: filename` pattern (old anti-pattern)
3. Uses `savedFilename = url.lastPathComponent` pattern
4. summary also uses savedFilename

## Scope

This policy applies to all artifact-generating tools:
- WriteTextFileTool (covered in Round 245A-P0)
- Future file-writing tools
- Tools that may trigger filename collision handling

## Related

- **ToolResult contract:** artifactPath type definition
- **safeWritableWorkspaceURL:** Responsible for actual filename logic
- **RecentArtifactResolver:** Consumer of artifactPath
