# Runtime QA Playbook

## 1. Sample Files

```bash
mkdir -p /tmp/myteam-qa
cat > /tmp/myteam-qa/sample.md <<'EOF'
# 테스트 회의

- 앱 파일 읽기 기능을 추가했다.
- txt, md, csv만 먼저 지원한다.
- pdf, docx, xlsx, pptx는 준비 중이다.
- 다음 작업은 QA burn-in이다.
EOF

cat > /tmp/myteam-qa/sample.csv <<'EOF'
항목,상태,비고
파일 읽기,완료,txt md csv 우선
PDF,준비중,파서 미구현
QA,진행중,런타임 확인 필요
EOF

touch /tmp/myteam-qa/empty.txt
printf 'hello\n%.0s' {1..400000} > /tmp/myteam-qa/large.txt
cat > /tmp/myteam-qa/run.sh <<'EOF'
echo unsafe
EOF
touch /tmp/myteam-qa/sample.pdf
touch /tmp/myteam-qa/sample.docx
touch /tmp/myteam-qa/sample.xlsx
touch /tmp/myteam-qa/sample.pptx
```

## 2. File Intake QA

- `sample.md`, `sample.csv` 선택
- `sample.pdf`, `sample.docx`, `sample.xlsx`, `sample.pptx` 선택
- `run.sh` 선택
- `large.txt` 선택
- `empty.txt` 선택

## 3. File to Document QA

- `파일 요약해줘`
- `이 파일 보고서로 만들어줘`
- `파일 내용을 표로 정리해줘`
- `파일 체크리스트 만들어줘`
- `파일 회의록으로 정리해줘`
- `파일 액션아이템 뽑아줘`

## 4. Blocked Capability QA

- `자동으로 로그인해서 일정 가져와`
- `메일 보내줘`
- `일정 만들어줘`
- `파일 삭제해줘`

## 5. PlanRunner Flag QA

```bash
defaults write com.urang.MyTeam MyTeam.FeatureFlags.planRunnerUniversalDocumentEnabled -bool true
```

- DEBUG helper로 토글 확인 후 반드시 `false`로 복구

## 6. 기록 규칙

- `runtime pass`
- `runtime failed`
- `still unverified`
- 원문, 토큰, 전체 경로는 적지 않는다

## 7. Round 30C Checklist

- Daily Briefing: 오늘 브리핑 해줘 / 오늘 일정 뭐 있어? / 오늘 뭐 해야 해? / 메일이랑 일정 보고 오늘 할 일 정리해줘 / 새 메일 몇 통 왔어? / 중요한 메일만 알려줘 / 이번 주 일정 요약해줘
- Forbidden routes: 앱스토어 설명문, 개인정보처리방침, 파일 요약, 보고서, PPT, 엑셀
- ConnectorGuard: calendarRead, mailMetadataRead, mailBodyRead, mailSummarize, mailDraft, mailSend, calendarCreate, calendarModify, automaticLogin, destructiveFileAction
- diagnostics: connector blocked actions are truncated, no tokens or paths

## 8. Deferred Runtime QA Backlog

### UI Interaction QA
- Finder open
- path copy
- fileImporter sandbox
- action chip tap

### Multi-room Runtime QA
- active task isolation
- wrong-room artifact reuse
- pending delegation resume

### Connector QA
- Google Calendar live OAuth
- Gmail metadata later

### Release QA
- debug toggles hidden
- diagnostics minimized
- PlanRunner default false

## 9. ArtifactStore Policy Notes

- ArtifactStore health, relative path normalize, and cleanup dry-run are policy-level checks only
- 실제 cleanup delete QA는 하지 않는다
- full path, sourceText, token, auth는 기록하지 않는다
