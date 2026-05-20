#!/usr/bin/env python3
"""
Register Round 248TTS-A new Swift files to Xcode project.

Files to register:
- ONNXRuntimeAdapter.swift
- Supertonic3TensorTypes.swift
- Supertonic3ModelManifest.swift
- Supertonic3InferencePipeline.swift

This script uses Python's plistlib to modify project.pbxproj
and add the files to PBXSourcesBuildPhase.
"""

import sys
import os
import plistlib
import uuid
from pathlib import Path

# Files to register
FILENAMES = [
    "ONNXRuntimeAdapter.swift",
    "Supertonic3TensorTypes.swift",
    "Supertonic3ModelManifest.swift",
    "Supertonic3InferencePipeline.swift",
]

def find_pbxproj():
    """Find the project.pbxproj file."""
    project_path = Path("MyTeam/MyTeam.xcodeproj/project.pbxproj")
    if not project_path.exists():
        print(f"ERROR: {project_path} not found")
        sys.exit(1)
    return project_path

def load_pbxproj(pbxproj_path):
    """Load project.pbxproj as plist."""
    with open(pbxproj_path, "rb") as f:
        return plistlib.load(f)

def save_pbxproj(pbxproj_path, data):
    """Save project plist back to file."""
    with open(pbxproj_path, "wb") as f:
        plistlib.dump(data, f)

def register_files(pbxproj_path):
    """Register files to pbxproj."""
    print(f"Loading {pbxproj_path}...")
    data = load_pbxproj(pbxproj_path)

    # Get or create file references dictionary
    objects = data.get("objects", {})
    file_refs = {}
    sources_phase_ref = None

    # Find PBXSourcesBuildPhase
    for key, obj in objects.items():
        if isinstance(obj, dict):
            isa = obj.get("isa")
            if isa == "PBXSourcesBuildPhase":
                sources_phase_ref = key
                break

    if not sources_phase_ref:
        print("ERROR: Could not find PBXSourcesBuildPhase")
        sys.exit(1)

    sources_phase = objects[sources_phase_ref]
    files = sources_phase.get("files", [])

    # Register each file
    registered_count = 0
    for filename in FILENAMES:
        # Check if already registered
        already_exists = False
        for ref in files:
            if isinstance(ref, dict) and ref.get("path") == filename:
                already_exists = True
                break

        if already_exists:
            print(f"  ⓘ {filename} already registered, skipping")
            continue

        # Create file reference
        file_ref_id = uuid.uuid4().hex[:24].upper()
        build_file_id = uuid.uuid4().hex[:24].upper()

        file_ref = {
            "isa": "PBXFileReference",
            "name": filename,
            "path": filename,
            "sourceTree": "SOURCE_ROOT",
            "fileEncoding": 4,
            "lastKnownFileType": "sourcecode.swift",
        }

        build_file = {
            "isa": "PBXBuildFile",
            "fileRef": file_ref_id,
        }

        objects[file_ref_id] = file_ref
        objects[build_file_id] = build_file
        files.append({"object": build_file_id})

        print(f"  ✓ Registered {filename}")
        registered_count += 1

    sources_phase["files"] = files
    data["objects"] = objects

    print(f"\nSaving {pbxproj_path}...")
    save_pbxproj(pbxproj_path, data)
    print(f"✓ {registered_count} files registered")

if __name__ == "__main__":
    pbxproj = find_pbxproj()
    register_files(pbxproj)
    print("\n✓ Round 248TTS-A file registration complete")
