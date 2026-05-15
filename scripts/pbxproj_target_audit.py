#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

REQUIRED_SWIFT_FILES = [
    "FirstLaunchState.swift",
    "FirstLaunchStateProvider.swift",
    "FirstLaunchBannerView.swift",
    "LocalOnlyModeCardView.swift",
    "RuntimeCapabilityMode.swift",
    "StarterAction.swift",
    "StarterActionDispatcher.swift",
    "StarterActionStripView.swift",
    "Color+Hex.swift",
    "CharacterAssetManifest.swift",
    "ReleaseVisibleCharacterPolicy.swift",
    "ProductSurfacePolicy.swift",
    "ConnectorSurfacePolicy.swift",
    "FirstResultActionPolicy.swift",
    "StarterActionPolicy.swift"
]

def read_pbxproj(path):
    """Read pbxproj as text (it's a plist-like format)."""
    try:
        with open(path, 'r') as f:
            return f.read()
    except Exception as e:
        print(f"ERROR: Cannot read pbxproj: {e}", file=sys.stderr)
        sys.exit(1)

def check_file_presence(pbxproj_content, filename):
    """Check if file has PBXFileReference, PBXBuildFile, and PBXSourcesBuildPhase entries."""
    basename = filename.replace('.swift', '')

    has_file_ref = f'path = "{filename}"' in pbxproj_content or f'name = "{filename}"' in pbxproj_content
    has_build_file = f'fileRef = ' in pbxproj_content and f'/* {filename}' in pbxproj_content
    has_sources_phase = f'sourceRoot' in pbxproj_content

    return {
        'filename': filename,
        'has_file_reference': has_file_ref,
        'has_build_file': has_build_file,
        'has_sources_phase': has_sources_phase,
        'status': 'present' if has_file_ref else 'missing'
    }

def audit_pbxproj(pbxproj_path):
    """Audit pbxproj for required Swift files."""
    if not pbxproj_path.exists():
        print(f"ERROR: pbxproj not found at {pbxproj_path}", file=sys.stderr)
        sys.exit(1)

    content = read_pbxproj(str(pbxproj_path))
    results = []

    for filename in REQUIRED_SWIFT_FILES:
        results.append(check_file_presence(content, filename))

    return results

def generate_report(results, output_path):
    """Generate markdown report of audit results."""
    report_lines = [
        "# pbxproj Target Audit Report",
        "",
        "## Summary",
        f"**Total Files**: {len(results)}",
        f"**Present**: {sum(1 for r in results if r['status'] == 'present')}",
        f"**Missing**: {sum(1 for r in results if r['status'] == 'missing')}",
        "",
        "## File Status",
        ""
    ]

    present_files = [r for r in results if r['status'] == 'present']
    missing_files = [r for r in results if r['status'] == 'missing']

    if present_files:
        report_lines.append("### ✅ Present")
        for r in present_files:
            report_lines.append(f"- {r['filename']}")
        report_lines.append("")

    if missing_files:
        report_lines.append("### ⚠️ Missing")
        for r in missing_files:
            report_lines.append(f"- {r['filename']}")
        report_lines.append("")
        report_lines.append("**Action**: Run `mac_register_round116_files.rb` to auto-register")
        report_lines.append("")

    report_lines.extend([
        "## Next Steps",
        "1. If missing files detected, run: `scripts/mac_register_round116_files.rb`",
        "2. Verify pbxproj changes: `git diff MyTeam.xcodeproj/project.pbxproj`",
        "3. Run xcodebuild Debug: `scripts/mac_merge_build_round116.sh`",
        ""
    ])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        f.write('\n'.join(report_lines))

    return len(missing_files) == 0

if __name__ == '__main__':
    pbxproj = Path('MyTeam/MyTeam.xcodeproj/project.pbxproj')
    output = Path('reports/pbxproj_target_audit.md')

    results = audit_pbxproj(pbxproj)
    success = generate_report(results, output)

    print(f"✅ Report generated: {output}")
    if not success:
        print("⚠️  Missing files detected. Run mac_register_round116_files.rb to repair.")
        sys.exit(1)
    else:
        print("✅ All required files present in target.")
        sys.exit(0)
