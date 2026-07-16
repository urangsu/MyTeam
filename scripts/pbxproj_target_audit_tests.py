#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("pbxproj_target_audit.py")
SPEC = importlib.util.spec_from_file_location("pbxproj_target_audit", MODULE_PATH)
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class PBXProjTargetAuditTests(unittest.TestCase):
    def test_detects_swift_file_reference_in_xml_plist_project(self):
        project = """
        <dict>
          <key>isa</key><string>PBXFileReference</string>
          <key>path</key><string>FirstLaunchState.swift</string>
        </dict>
        """

        result = AUDIT.check_file_presence(project, "FirstLaunchState.swift")

        self.assertEqual(result["status"], "present")
        self.assertTrue(result["has_file_reference"])


if __name__ == "__main__":
    unittest.main()
