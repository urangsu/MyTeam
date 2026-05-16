# Repair Build (Quick Reference)

**When:** Build fails with "cannot find type in scope" or pbxproj issues

## Checklist

```bash
# 1. Verify git state
git status
git log --oneline -5

# 2. Check pbxproj membership (if adding new files)
grep -n "NewFile.swift" MyTeam/MyTeam.xcodeproj/project.pbxproj || echo "File not in pbxproj"

# 3. Clean build
xcodebuild -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug clean build

# 4. If module compile fails, check:
# - Type visibility (public, internal, fileprivate)
# - No #if DEBUG blocking in Release
# - File order dependencies in pbxproj
```

## Common Fixes

**"cannot find type X in scope"**
- File not in pbxproj build sources → add via XML edit
- Enum not exported → check access level
- Compilation order issue → revert change, use wrapper approach

**pbxproj edit:** Use plutil + XML string manipulation
```python
subprocess.run(["plutil", "-convert", "xml1", "-o", path, pbxproj])
# edit XML
subprocess.run(["plutil", "-convert", "binary1", "-o", pbxproj, path])
```

## Never

- ❌ Modify pbxproj directly as text
- ❌ Use Xcode GUI for file management
- ❌ Commit broken build
- ❌ Skip validation before pushing
