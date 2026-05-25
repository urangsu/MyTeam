#!/bin/bash
# App Store Screenshots Generation Script
# Purpose: Automate screenshot capture for App Store submission
# Usage: bash scripts/generate_appstore_screenshots.sh
# Output: screenshots/ directory with 1280x800 PNGs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$REPO_ROOT/screenshots"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ensure screenshots directory exists
mkdir -p "$SCREENSHOTS_DIR"

echo "=========================================="
echo "App Store Screenshots Generation"
echo "=========================================="
echo ""

# Note: This script provides a template for screenshot generation.
# Actual screenshot capture requires:
# 1. Running app on macOS (not available in cloud)
# 2. Window resizing to 1280x800
# 3. Manual screen capture (⌘⇧4)
# 4. Optional: Image cropping and annotation

echo "📸 Screenshot Requirements:"
echo "---"
echo "Format: PNG or JPG"
echo "Size: 1280×800 (landscape)"
echo "Count: 3-5 per language"
echo "Languages: English + Korean"
echo ""

echo "📋 Recommended Screenshot Sequence:"
echo "---"
echo ""
echo "Screenshot 1: Main Chat + Artifact"
echo "  Title: 'AI와 함께 문서 만들기' (KO) / 'Create Documents with AI' (EN)"
echo "  Show:"
echo "    - Chat message: '회의록 만들어줘' (KO)"
echo "    - AI response (partial view)"
echo "    - Artifact card with file name"
echo "    - 'Finder 열기' and '경로 복사' buttons visible"
echo ""

echo "Screenshot 2: File Organization"
echo "  Title: '파일을 드래그해서 정리하기' (KO) / 'Drag Files to Organize' (EN)"
echo "  Show:"
echo "    - File import action (drag indicator or file picker)"
echo "    - Imported file content in chat"
echo "    - Analysis response"
echo ""

echo "Screenshot 3: Settings + Local Features"
echo "  Title: '로컬 기능 + AI 선택' (KO) / 'Local Features + AI Choice' (EN)"
echo "  Show:"
echo "    - Settings view with API key input"
echo "    - 'Connect API provider' section"
echo "    - File format support list (txt, md, csv, pdf preparing)"
echo ""

echo "🖥️  Manual Screenshot Steps:"
echo "---"
echo "1. Build and run Debug or Release configuration"
echo "2. Position window at 1280×800 resolution"
echo "3. Set up desired state (chat, file, or settings)"
echo "4. macOS: Press ⌘⇧4 to screenshot"
echo "5. Select window → saves to Desktop as PNG"
echo "6. Move to $SCREENSHOTS_DIR/"
echo "7. Rename: myteam-{lang}-1280x800-{n}.png"
echo "   Example: myteam-ko-1280x800-1.png"
echo "           myteam-en-1280x800-1.png"
echo ""

echo "✅ File naming template:"
echo "---"
ls -la "$SCREENSHOTS_DIR" 2>/dev/null || echo "  (No screenshots yet. Create directory and capture.)"
echo ""

echo "📦 Directory structure after capture:"
echo "---"
echo "screenshots/"
echo "  myteam-en-1280x800-1.png  (Screenshot 1, English)"
echo "  myteam-ko-1280x800-1.png  (Screenshot 1, Korean)"
echo "  myteam-en-1280x800-2.png  (Screenshot 2, English)"
echo "  myteam-ko-1280x800-2.png  (Screenshot 2, Korean)"
echo "  myteam-en-1280x800-3.png  (Screenshot 3, English)"
echo "  myteam-ko-1280x800-3.png  (Screenshot 3, Korean)"
echo ""

echo "🚀 Next steps:"
echo "---"
echo "1. Run this script to understand structure"
echo "2. On macOS: Launch app with desired state"
echo "3. Capture 3-5 screenshots per language"
echo "4. Rename files to match pattern above"
echo "5. Upload to App Store Connect"
echo ""

echo "✅ Directory ready: $SCREENSHOTS_DIR"
echo "Ready for manual screenshot capture on macOS."
echo ""
