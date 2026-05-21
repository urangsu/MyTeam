#!/usr/bin/env python3
"""Register Round 247A-OBSERVE-RUNTIME new Swift files to Xcode project."""

import sys
import os
import plistlib
import uuid
from pathlib import Path

FILENAMES = [
    "ObservationInboxView.swift",
    "ObservationPresentationPolicy.swift",
    "OfficeReviewLiteExecutor.swift",
    "OfficeReviewResultCardView.swift",
]

def find_pbxproj():
    project_path = Path("MyTeam/MyTeam.xcodeproj/project.pbxproj")
    if not project_path.exists():
        print(f"ERROR: {project_path} not found")
        sys.exit(1)
    return project_path

def load_pbxproj(pbxproj_path):
    with open(pbxproj_path, "rb") as f:
        return plistlib.load(f)

def save_pbxproj(pbxproj_path, data):
    with open(pbxproj_path, "wb") as f:
        plistlib.dump(data, f)

def register_files(pbxproj_path):
    print(f"Loading {pbxproj_path}...")
    data = load_pbxproj(pbxproj_path)
    objects = data.get("objects", {})
    sources_phase_ref = None

    for key, obj in objects.items():
        if isinstance(obj, dict) and obj.get("isa") == "PBXSourcesBuildPhase":
            sources_phase_ref = key
            break

    if not sources_phase_ref:
        print("ERROR: Could not find PBXSourcesBuildPhase")
        sys.exit(1)

    sources_phase = objects[sources_phase_ref]
    files = sources_phase.get("files", [])

    registered_count = 0
    for filename in FILENAMES:
        already_exists = any(
            isinstance(ref, dict) and ref.get("path") == filename
            for ref in files
        )
        if already_exists:
            print(f"  ⓘ {filename} already registered, skipping")
            continue

        file_ref_id = uuid.uuid4().hex[:24].upper()
        build_file_id = uuid.uuid4().hex[:24].upper()

        objects[file_ref_id] = {
            "isa": "PBXFileReference",
            "name": filename,
            "path": filename,
            "sourceTree": "SOURCE_ROOT",
            "fileEncoding": 4,
            "lastKnownFileType": "sourcecode.swift",
        }
        objects[build_file_id] = {
            "isa": "PBXBuildFile",
            "fileRef": file_ref_id,
        }
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
    print("\n✓ Round 247A-OBSERVE file registration complete")
