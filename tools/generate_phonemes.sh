#!/bin/bash
# ============================================================
# generate_phonemes.sh
# espeak-ng으로 한국어 음소 WAV를 생성하고
# Animal Crossing 스타일로 가공합니다. (1회 실행)
#
# 사용법:
#   ./generate_phonemes.sh
#
# 결과물:
#   ../MyTeam/MyTeam/Resources/Phonemes/*.wav
#   → Xcode에서 이 폴더를 Assets에 추가하세요
# ============================================================

set -e

OUTPUT_DIR="../MyTeam/MyTeam/Resources/Phonemes"
mkdir -p "$OUTPUT_DIR"

echo "🔊 espeak-ng 한국어 음소 생성 시작..."
echo ""

# ── 생성할 음소 목록 ──────────────────────────────────────
# 형식: "파일명:발음텍스트:피치"
# 한글 중성(모음) 21개 + 자주 쓰는 음절 추가
PHONEMES=(
    # 기본 모음
    "a:아:55"
    "ae:애:55"
    "ya:야:58"
    "yae:얘:58"
    "eo:어:52"
    "e:에:55"
    "yeo:여:55"
    "ye:예:55"
    "o:오:52"
    "wa:와:55"
    "wae:왜:55"
    "oe:외:55"
    "yo:요:55"
    "u:우:48"
    "wo:워:50"
    "we:웨:52"
    "wi:위:58"
    "yu:유:52"
    "eu:으:48"
    "ui:의:52"
    "i:이:62"

    # 자음+모음 (자주 쓰이는 음절)
    "na:나:55"
    "ne:네:55"
    "ni:니:58"
    "no:노:52"
    "nu:누:50"
    "ma:마:55"
    "me:메:55"
    "mi:미:58"
    "mo:모:52"
    "mu:무:50"
    "ra:라:55"
    "re:레:55"
    "ri:리:58"
    "ro:로:52"
    "ru:루:50"
    "sa:사:55"
    "se:세:55"
    "si:시:60"
    "so:소:52"
    "su:수:50"
    "ha:하:55"
    "he:헤:55"
    "hi:히:60"
    "ho:호:52"
    "hu:후:50"
    "ka:가:55"
    "ke:게:55"
    "ki:기:58"
    "ko:고:52"
    "ku:구:50"
    "ta:다:55"
    "te:데:55"
    "ti:디:58"
    "to:도:52"
    "tu:두:50"
    "ba:바:55"
    "be:베:55"
    "bi:비:58"
    "bo:보:52"
    "bu:부:50"
    "ja:자:55"
    "je:제:55"
    "ji:지:58"
    "jo:조:52"
    "ju:주:50"
    "cha:차:55"
    "che:체:55"
    "chi:치:60"
    "cho:초:52"
    "chu:추:50"
)

TOTAL=${#PHONEMES[@]}
COUNT=0

for item in "${PHONEMES[@]}"; do
    IFS=':' read -r filename text pitch <<< "$item"
    OUTFILE="$OUTPUT_DIR/${filename}.wav"
    TMPFILE="/tmp/phoneme_raw_${filename}.wav"

    # espeak-ng으로 원본 WAV 생성
    # -v ko     : 한국어 목소리
    # -s 160    : 말하기 속도 (낮을수록 또렷한 음소)
    # -p $pitch : 피치 (0~99, 높을수록 고음)
    # -a 80     : 볼륨
    espeak-ng -v ko -s 160 -p "$pitch" -a 80 "$text" -w "$TMPFILE" 2>/dev/null

    # ffmpeg으로 Animal Crossing 스타일 가공:
    # 1. 앞 무음 제거 (silenceremove)
    # 2. 100ms로 자르기
    # 3. fade out 20ms (자연스러운 끝처리)
    # 4. 16kHz 모노로 리샘플 (파일 크기 최소화)
    ffmpeg -y -i "$TMPFILE" \
        -af "silenceremove=start_periods=1:start_silence=0.01:start_threshold=-45dB,atrim=end=0.10,afade=t=out:st=0.07:d=0.03" \
        -ar 16000 -ac 1 \
        "$OUTFILE" -loglevel error 2>/dev/null

    rm -f "$TMPFILE"

    COUNT=$((COUNT + 1))
    printf "   [%2d/%d] %-10s %s\n" "$COUNT" "$TOTAL" "${filename}.wav" "$text"
done

echo ""
echo "✅ $COUNT개 음소 생성 완료!"
echo "   저장 위치: $OUTPUT_DIR"
echo ""

# 파일 크기 확인
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo "   폴더 총 크기: $TOTAL_SIZE"
echo ""
echo "══════════════════════════════════════════"
echo "📌 다음 단계:"
echo "   1. Xcode 프로젝트 열기"
echo "   2. MyTeam/MyTeam/Resources/ 폴더를"
echo "      Project Navigator에 드래그"
echo "   3. 옵션: ✅ Copy items if needed"
echo "   4. 앱 빌드 & 실행"
echo "══════════════════════════════════════════"
