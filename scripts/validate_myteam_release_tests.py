#!/usr/bin/env python3
import tempfile
import unittest
from pathlib import Path

from validate_myteam_release import find_forbidden_swift_matches


class ForbiddenSwiftPatternTests(unittest.TestCase):
    def test_finds_matching_swift_line_with_repository_relative_location(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "MyTeam" / "Settings.swift"
            source.parent.mkdir(parents=True)
            source.write_text('let apiKey = UserDefaults.standard.string(forKey: "apiKey")\n')

            matches = find_forbidden_swift_matches(
                root,
                r"UserDefaults.*apiKey|apiKey.*UserDefaults",
            )

            self.assertEqual(
                matches,
                [
                    'MyTeam/Settings.swift:1:let apiKey = UserDefaults.standard.string(forKey: "apiKey")'
                ],
            )

    def test_ignores_non_swift_and_legacy_tool_sources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            legacy = root / "MyTeam" / "tools" / "legacy" / "Legacy.swift"
            text = root / "MyTeam" / "Notes.txt"
            legacy.parent.mkdir(parents=True)
            legacy.write_text('let apiKey = UserDefaults.standard.string(forKey: "apiKey")\n')
            text.write_text('let apiKey = UserDefaults.standard.string(forKey: "apiKey")\n')

            matches = find_forbidden_swift_matches(
                root,
                r"UserDefaults.*apiKey|apiKey.*UserDefaults",
            )

            self.assertEqual(matches, [])


if __name__ == "__main__":
    unittest.main()
