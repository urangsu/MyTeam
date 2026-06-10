#!/usr/bin/env python3
import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APPSTORE_ENTITLEMENTS = ROOT / "MyTeam" / "MyTeam.AppStore.entitlements"
REPO_SOURCES = ROOT / "MyTeam"
PROJECT_FILE = ROOT / "MyTeam" / "MyTeam.xcodeproj" / "project.pbxproj"


FORBIDDEN_APPSTORE_ENTITLEMENTS = {
    "com.apple.security.temporary-exception.files.absolute-path.read-only",
    "com.apple.security.temporary-exception.files.absolute-path.read-write",
    "com.apple.security.files.all",
    "com.apple.security.automation.with-user-interaction",
    "com.apple.security.device.camera",
    "com.apple.security.device.microphone",
    "com.apple.security.device.location",
}


REQUIRED_FALSE_POLICY_PATTERNS = [
    r"case \.appStore:\s*return RuntimeFeaturePolicy\([\s\S]*?allowsExternalProcess:\s*false",
    r"case \.appStore:\s*return RuntimeFeaturePolicy\([\s\S]*?allowsPlaywrightMCP:\s*false",
    r"case \.appStore:\s*return RuntimeFeaturePolicy\([\s\S]*?allowsExperimentalConnectors:\s*false",
    r"case \.appStore:\s*return RuntimeFeaturePolicy\([\s\S]*?allowsVoiceAPI:\s*false",
    r"nonisolated static var allowsModelAutoDownload:\s*Bool\s*\{\s*false\s*\}",
]


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing file: {path.relative_to(ROOT)}")


def validate_entitlements() -> None:
    if not APPSTORE_ENTITLEMENTS.exists():
        fail("MyTeam/MyTeam.AppStore.entitlements is required")

    with APPSTORE_ENTITLEMENTS.open("rb") as fh:
        entitlements = plistlib.load(fh)

    if entitlements.get("com.apple.security.app-sandbox") is not True:
        fail("App Store entitlements must enable app sandbox")

    if entitlements.get("com.apple.security.network.client") is not True:
        fail("App Store entitlements must keep network client enabled")

    for key in FORBIDDEN_APPSTORE_ENTITLEMENTS:
        if key in entitlements:
            fail(f"forbidden App Store entitlement present: {key}")


def validate_xcode_build_settings() -> None:
    if not PROJECT_FILE.exists():
        fail("MyTeam/MyTeam.xcodeproj/project.pbxproj is required")

    with PROJECT_FILE.open("rb") as fh:
        project = plistlib.load(fh)

    app_configs = []
    for object_id, obj in project.get("objects", {}).items():
        if obj.get("isa") != "XCBuildConfiguration":
            continue
        settings = obj.get("buildSettings", {})
        if settings.get("PRODUCT_BUNDLE_IDENTIFIER") != "com.urang.MyTeam":
            continue
        app_configs.append((object_id, obj.get("name"), settings))

    if not app_configs:
        fail("could not find MyTeam app target build settings")

    release_configs = [(object_id, settings) for object_id, name, settings in app_configs if name == "Release"]
    debug_configs = [(object_id, settings) for object_id, name, settings in app_configs if name == "Debug"]
    if not release_configs:
        fail("could not find MyTeam Release build settings")

    for object_id, settings in release_configs:
        entitlements = settings.get("CODE_SIGN_ENTITLEMENTS")
        if entitlements != "MyTeam.AppStore.entitlements":
            fail(f"Release config {object_id} must use MyTeam.AppStore.entitlements")
        if settings.get("ENABLE_APP_SANDBOX") != "YES":
            fail(f"Release config {object_id} must enable app sandbox")
        if settings.get("ENABLE_OUTGOING_NETWORK_CONNECTIONS") != "YES":
            fail(f"Release config {object_id} must keep outgoing network enabled")
        if settings.get("ENABLE_USER_SELECTED_FILES") not in {"readonly", "readwrite"}:
            fail(f"Release config {object_id} must use user-selected file access only")

    for object_id, settings in debug_configs:
        entitlements = settings.get("CODE_SIGN_ENTITLEMENTS")
        if entitlements and entitlements in {"MyTeam.entitlements", "MyTeam/MyTeam.entitlements"}:
            fail(f"Debug config {object_id} still references legacy MyTeam.entitlements")


def validate_policy_sources() -> None:
    release_profile = read_text(REPO_SOURCES / "AppReleaseProfile.swift")
    feature_gate = read_text(REPO_SOURCES / "DistributionChannel.swift")
    combined = release_profile + "\n" + feature_gate
    for pattern in REQUIRED_FALSE_POLICY_PATTERNS:
        if not re.search(pattern, combined):
            fail(f"required App Store policy pattern missing: {pattern}")


def validate_supertonic3_policy() -> None:
    source_policy = read_text(REPO_SOURCES / "Supertonic3ModelSource.swift")
    routing_policy = read_text(REPO_SOURCES / "TTSRoutingPolicy.swift")
    external_locator = read_text(REPO_SOURCES / "Supertonic3ExternalCacheModelLocator.swift")
    onnx_paths = read_text(REPO_SOURCES / "Supertonic3ONNXModelPaths.swift")

    if not re.search(r"case \.appStore:\s*return \.bundled", source_policy):
        fail("Supertonic3 App Store model source must be bundled")
    if not re.search(r"case \.developer:\s*return \.externalCacheDeveloperOnly", source_policy):
        fail("Supertonic3 external cache must be Developer-only")
    if not re.search(r"case \.appStore:\s*return AppStoreTTSReleaseGate\.isApproved", source_policy):
        fail("Supertonic3 App Store runtime must be gated by AppStoreTTSReleaseGate")
    if "enum AppStoreTTSReleaseGate" not in source_policy:
        fail("Supertonic3 App Store release gate must be explicit")
    if "bundledModelValidated" not in source_policy:
        fail("Supertonic3 App Store release gate must validate bundled model files")
    if "FeatureGate.current == .developer" not in external_locator:
        fail("Supertonic3 external cache locator must guard Developer profile")
    if "Supertonic3DistributionGate.isRuntimeAllowed" not in routing_policy:
        fail("TTS routing must include Supertonic3 distribution gate")
    if "Supertonic3ModelAvailability.isReady" not in routing_policy:
        fail("TTS routing must include Supertonic3 model availability")
    if "Supertonic3TTSConfig.modelDirectoryURL" in onnx_paths:
        fail("Supertonic3ONNXModelPaths must not read external cache directly")


def validate_release_ui_strings() -> None:
    visible_files = [
        REPO_SOURCES / "SettingsView.swift",
        REPO_SOURCES / "ConnectionCenterView.swift",
        REPO_SOURCES / "AssistantConnectorCenterView.swift",
    ]
    forbidden = ["Playwright MCP", "node", "npx"]
    for path in visible_files:
        text = read_text(path)
        for marker in forbidden:
            if marker in text and "showsDeveloperDiagnostics" not in text and "#if DEBUG" not in text:
                fail(f"release-visible diagnostics marker '{marker}' found in {path.relative_to(ROOT)}")


def main() -> None:
    validate_entitlements()
    validate_xcode_build_settings()
    validate_policy_sources()
    validate_supertonic3_policy()
    validate_release_ui_strings()
    print("PASS: App Store profile policy checks")


if __name__ == "__main__":
    main()
