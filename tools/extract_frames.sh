#!/bin/bash
# ============================================================
# extract_frames.sh
# 나노바나나에서 렌더한 MP4를 PNG 시퀀스로 변환하고
# 배경을 자동으로 제거하는 스크립트
#
# 사용법:
#   ./extract_frames.sh <input.mp4> <animation_name>
#   예시: ./extract_frames.sh sloth_idle.mp4 sloth_idle
#
# 결과물 위치:
#   output/<animation_name>/frame_001.png  (배경 제거 완료)
# ============================================================

set -e  # 에러 발생 시 즉시 중단

INPUT_FILE="$1"
ANIM_NAME="$2"

# ── 인자 확인 ──────────────────────────────────────────────
if [ -z "$INPUT_FILE" ] || [ -z "$ANIM_NAME" ]; then
    echo "❌ 사용법: ./extract_frames.sh <input.mp4> <animation_name>"
    echo "   예시:   ./extract_frames.sh sloth_idle.mp4 sloth_idle"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ 파일을 찾을 수 없습니다: $INPUT_FILE"
    exit 1
fi

# ── 의존성 확인 ────────────────────────────────────────────
echo "🔍 필요한 도구 확인 중..."

if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg이 설치되어 있지 않습니다."
    echo "   설치 방법: brew install ffmpeg"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python3이 설치되어 있지 않습니다."
    exit 1
fi

# rembg 설치 여부 확인
if ! python3 -c "import rembg" &> /dev/null; then
    echo "📦 rembg 라이브러리 설치 중... (최초 1회만 실행)"
    pip3 install rembg
fi

# ── 디렉토리 설정 ──────────────────────────────────────────
RAW_DIR="output/${ANIM_NAME}/raw"
FINAL_DIR="output/${ANIM_NAME}"

mkdir -p "$RAW_DIR"
mkdir -p "$FINAL_DIR"

echo ""
echo "🎬 STEP 1: MP4 → PNG 시퀀스 추출"
echo "   입력: $INPUT_FILE"
echo "   출력: $RAW_DIR"
echo "   FPS: 12 (SpriteKit 권장)"
echo ""

# FPS=12로 추출 (SpriteKit 애니메이션에 최적화된 값)
# -vf fps=12  : 초당 12프레임으로 추출
# -vframes 120: 최대 120프레임까지만 (10초 분량)
# %03d.png    : 001.png, 002.png ... 형식으로 저장
ffmpeg -i "$INPUT_FILE" \
       -vf fps=12 \
       -vframes 120 \
       "$RAW_DIR/%03d.png" \
       -loglevel warning

FRAME_COUNT=$(ls "$RAW_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
echo "✅ $FRAME_COUNT 프레임 추출 완료"

echo ""
echo "🎨 STEP 2: 배경 제거 (rembg)"
echo "   처음 실행 시 AI 모델 다운로드로 1~2분 소요될 수 있습니다."
echo ""

# Python으로 rembg 일괄 처리
python3 << EOF
import os
import sys
from pathlib import Path

try:
    from rembg import remove
    from PIL import Image
except ImportError:
    print("❌ rembg 또는 Pillow 라이브러리가 없습니다.")
    print("   pip3 install rembg Pillow")
    sys.exit(1)

raw_dir = Path("$RAW_DIR")
final_dir = Path("$FINAL_DIR")
png_files = sorted(raw_dir.glob("*.png"))

print(f"   총 {len(png_files)}개 프레임 처리 중...")

for i, png_path in enumerate(png_files):
    # 배경 제거 처리
    with open(png_path, "rb") as f:
        input_data = f.read()

    output_data = remove(input_data)

    # 최종 파일명: frame_001.png 형식
    output_filename = f"frame_{i+1:03d}.png"
    output_path = final_dir / output_filename

    with open(output_path, "wb") as f:
        f.write(output_data)

    # 진행 상황 표시
    progress = (i + 1) / len(png_files) * 100
    print(f"   [{i+1:3d}/{len(png_files)}] {progress:.0f}% 완료 - {output_filename}", flush=True)

print(f"\n✅ 배경 제거 완료! {len(png_files)}개 파일 저장됨")
print(f"   저장 위치: $FINAL_DIR/")
EOF

echo ""
echo "🧹 STEP 3: 임시 파일 정리"
rm -rf "$RAW_DIR"
echo "   raw 폴더 삭제 완료"

echo ""
echo "=============================================="
echo "🎉 완료! 다음 단계:"
echo ""
echo "1. 아래 폴더를 Xcode 프로젝트에 드래그해서 추가하세요:"
echo "   $FINAL_DIR/"
echo ""
echo "2. Xcode에서 추가 시 체크 옵션:"
echo "   ✅ Copy items if needed"
echo "   ✅ Add to target: MyTeam"
echo ""
echo "3. SpriteAgentView에서 사용:"
echo "   SpriteAgentView(animationName: \"$ANIM_NAME\", frameCount: $FRAME_COUNT)"
echo "=============================================="
