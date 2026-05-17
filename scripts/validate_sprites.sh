#!/usr/bin/env bash
# validate_sprites.sh
# Round 234 Sprite Asset Validator
# Sprites/치코 intake 폴더와 MyTeam/Resources/Sprites/치코 런타임 폴더를 검사한다.
#
# 실패(exit 1): intake 폴더 구조 누락, README 누락, 파일명 컨벤션 위반
# 경고(exit 0): PNG 없음 (디자인 대기 상태), optional state 없음

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INTAKE_ROOT="$REPO_ROOT/Sprites"
RUNTIME_ROOT="$REPO_ROOT/MyTeam/Resources/Sprites"

FAILED=0
WARNED=0

pass()  { echo "✅ $1"; }
warn()  { echo "⚠️  $1"; WARNED=$((WARNED + 1)); }
fail()  { echo "❌ $1"; FAILED=$((FAILED + 1)); }

CHARACTERS=("치코" "세나" "카이" "유나")

REQUIRED_STATES_CHIKO=(idle typing thinking speaking greeting joy sad confused drag landing clockin backwork sleeping)
REQUIRED_STATES_SENA=(idle typing greeting joy)
REQUIRED_STATES_KAI=(idle typing greeting joy)
REQUIRED_STATES_YUNA=(idle typing greeting joy)

echo ""
echo "══════════════════════════════════════════════"
echo " Sprite Asset Validator — Round 234"
echo "══════════════════════════════════════════════"
echo ""

# ── 1. Intake 폴더 구조 확인 ─────────────────────────────
echo "[ 1/4 ] Intake 폴더 구조 확인"

if [ ! -d "$INTAKE_ROOT" ]; then
    fail "Sprites/ intake 폴더 없음: $INTAKE_ROOT"
else
    pass "Sprites/ intake 폴더 존재"
fi

if [ ! -f "$INTAKE_ROOT/README.md" ]; then
    fail "Sprites/README.md 없음"
else
    pass "Sprites/README.md 존재"
fi

for char in "${CHARACTERS[@]}"; do
    dir="$INTAKE_ROOT/$char"
    readme="$dir/README.md"
    if [ ! -d "$dir" ]; then
        fail "Sprites/$char/ 폴더 없음"
    elif [ ! -f "$readme" ]; then
        fail "Sprites/$char/README.md 없음"
    else
        pass "Sprites/$char/README.md 존재"
    fi
done

# ── 2. 런타임 폴더 확인 (치코만 — 나머지는 미출시) ──────
echo ""
echo "[ 2/4 ] 런타임 스프라이트 폴더 확인"

RUNTIME_CHIKO="$RUNTIME_ROOT/치코"
if [ ! -d "$RUNTIME_CHIKO" ]; then
    fail "MyTeam/Resources/Sprites/치코/ 없음"
else
    png_count=$(find "$RUNTIME_CHIKO" -name "*.png" | wc -l | tr -d ' ')
    pass "MyTeam/Resources/Sprites/치코/ 존재 ($png_count PNG)"
fi

# ── 3. 파일명 컨벤션 검사 ────────────────────────────────
echo ""
echo "[ 3/4 ] 파일명 컨벤션 검사"

for char in "${CHARACTERS[@]}"; do
    dir="$RUNTIME_ROOT/$char"
    [ -d "$dir" ] || continue  # 없으면 스킵 (미출시 캐릭터)

    # Python으로 컨벤션 검사 (macOS NFD 파일명 처리 — suffix 기반)
    # 검사: 파일명이 _NNN.png (3자리 숫자 suffix)로 끝나는지
    pyout=$(python3 - "$dir" "$char" <<'PYEOF'
import os, re, sys
dirpath = sys.argv[1]
charname = sys.argv[2]
bad = 0
try:
    files = sorted(os.listdir(dirpath))
except Exception as e:
    print(f"ERROR:{e}")
    sys.exit(0)
suffix_re = re.compile(r'_\d{3}\.png$')
for f in files:
    if not f.endswith('.png'):
        continue
    # Must end with _NNN.png
    if not suffix_re.search(f):
        print(f"MALFORMED:{f}")
        bad += 1
print(f"COUNT:{bad}")
PYEOF
)
    bad_files=$(echo "$pyout" | grep "^MALFORMED:" || true)
    actual_bad=$(echo "$pyout" | grep "^COUNT:" | sed 's/COUNT://' | tr -d '[:space:]')
    actual_bad=${actual_bad:-0}

    if [ -n "$bad_files" ]; then
        while IFS= read -r line; do
            fname="${line#MALFORMED:}"
            fail "컨벤션 위반 (suffix 없음): $fname"
        done <<< "$bad_files"
    fi

    if [ "$actual_bad" -eq 0 ]; then
        pass "$char: 파일명 컨벤션 통과"
    fi
done

# ── 4. Required state 최소 1 frame 확인 ──────────────────
echo ""
echo "[ 4/4 ] Required state 프레임 확인"

check_states() {
    local char="$1"
    local dir="$RUNTIME_ROOT/$char"
    shift
    local required=("$@")

    if [ ! -d "$dir" ]; then
        warn "$char: 런타임 폴더 없음 (DLC 대기)"
        return
    fi

    # Python으로 state별 frame count (macOS NFD 대응)
    local states_joined
    states_joined=$(printf '%s,' "${required[@]}")
    states_joined="${states_joined%,}"

    local pyresult
    pyresult=$(python3 - "$dir" "$states_joined" <<'PYEOF'
import os, re, sys
dirpath = sys.argv[1]
states = sys.argv[2].split(',')
try:
    files = os.listdir(dirpath)
except:
    for s in states:
        print(f"MISSING:{s}:0")
    sys.exit(0)
counts = {}
for f in files:
    if not f.endswith('.png'):
        continue
    m = re.search(r'_([a-z_]+)_\d{3}\.png$', f)
    if m:
        state = m.group(1)
        counts[state] = counts.get(state, 0) + 1
for s in states:
    c = counts.get(s, 0)
    print(f"STATE:{s}:{c}")
PYEOF
)

    while IFS= read -r line; do
        [[ "$line" == STATE:* ]] || continue
        IFS=: read -r _ st cnt <<< "$line"
        cnt="${cnt:-0}"
        if [ "$cnt" -eq 0 ]; then
            warn "$char/$st: 프레임 없음 (디자인 대기)"
        else
            pass "$char/$st: $cnt frames"
        fi
    done <<< "$pyresult"
}

check_states "치코" "${REQUIRED_STATES_CHIKO[@]}"
check_states "세나" "${REQUIRED_STATES_SENA[@]}"
check_states "카이" "${REQUIRED_STATES_KAI[@]}"
check_states "유나" "${REQUIRED_STATES_YUNA[@]}"

# ── 결과 요약 ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
    if [ "$WARNED" -gt 0 ]; then
        echo "✅ Sprite Validator 통과 ($WARNED 경고 — 디자인 대기 중)"
    else
        echo "✅ Sprite Validator 전체 통과 (0 실패, 0 경고)"
    fi
    echo "══════════════════════════════════════════════"
    exit 0
else
    echo "❌ Sprite Validator 실패: $FAILED 오류, $WARNED 경고"
    echo "══════════════════════════════════════════════"
    exit 1
fi
