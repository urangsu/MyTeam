#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Add missing Swift files to MyTeam target in pbxproj"""

import re
import uuid
import sys

pbxproj_path = 'MyTeam/MyTeam.xcodeproj/project.pbxproj'

# Files to add (Color+Hex.swift already exists)
files_to_add = [
    'FirstLaunchState.swift',
    'FirstLaunchStateProvider.swift',
    'FirstLaunchBannerView.swift',
    'LocalOnlyModeCardView.swift',
    'RuntimeCapabilityMode.swift',
    'StarterAction.swift',
    'StarterActionDispatcher.swift',
    'StarterActionStripView.swift',
]

try:
    with open(pbxproj_path, 'r', encoding='utf-8') as f:
        content = f.read()
except UnicodeDecodeError:
    print("Error: pbxproj has encoding issues, trying latin-1")
    with open(pbxproj_path, 'r', encoding='latin-1') as f:
        content = f.read()

# Find the end of PBXFileReference section
file_ref_section_match = re.search(r'/\* End PBXFileReference section \*/', content)
if not file_ref_section_match:
    print("Error: Could not find PBXFileReference section end")
    sys.exit(1)

file_ref_insert_pos = file_ref_section_match.start()

# Find PBXSourcesBuildPhase section
sources_phase_match = re.search(
    r'(PBXSourcesBuildPhase.*?files = \((.*?)\);)',
    content,
    re.DOTALL
)
if not sources_phase_match:
    print("Error: Could not find PBXSourcesBuildPhase files section")
    sys.exit(1)

sources_phase_start = sources_phase_match.start(2)

# Generate file references and build file references
file_refs_to_add = []
build_files_to_add = []

for filename in files_to_add:
    # Check if file already exists
    if f'/* {filename} */' in content:
        print(f"⚠️  File reference for {filename} already exists, skipping")
        continue

    # Generate unique IDs
    file_id = uuid.uuid4().hex[:24].upper()
    build_id = uuid.uuid4().hex[:24].upper()

    # Create file reference
    file_ref = f'''\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};
'''

    # Create build file entry for sources phase
    build_entry = f'''{build_id} /* {filename} in Sources */,
'''

    file_refs_to_add.append((file_id, file_ref))
    build_files_to_add.append((build_id, build_entry))

    print(f"✓ Will add {filename} with IDs {file_id}/{build_id}")

# Add file references to PBXFileReference section
all_file_refs = ''.join(ref for _, ref in file_refs_to_add)
if all_file_refs:
    content = content[:file_ref_insert_pos] + all_file_refs + content[file_ref_insert_pos:]
    print(f"\n✅ Added {len(file_refs_to_add)} file references to PBXFileReference section")

# Add build file entries to PBXSourcesBuildPhase
all_build_entries = ''.join(entry for _, entry in build_files_to_add)
if all_build_entries:
    # Find the position to insert (before the closing parenthesis)
    pattern = r'(PBXSourcesBuildPhase.*?files = \()(.*?)(\);)'
    def insert_builds(match):
        return match.group(1) + match.group(2).rstrip() + '\n\t\t\t\t' + all_build_entries.rstrip() + '\n\t\t\t' + match.group(3)

    content = re.sub(pattern, insert_builds, content, flags=re.DOTALL, count=1)
    print(f"✅ Added {len(build_files_to_add)} build files to PBXSourcesBuildPhase")

# Write back
try:
    with open(pbxproj_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ Successfully wrote updated pbxproj")
except Exception as e:
    print(f"\n❌ Error writing pbxproj: {e}")
    sys.exit(1)
