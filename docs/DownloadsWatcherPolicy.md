# Downloads Watcher Policy

**Round 243A-OBSERVE**

---

## 기본 정책

- **기본값: OFF** — 사용자가 명시적으로 활성화해야 동작
- **메타데이터만** — 파일명, 확장자, 크기, 생성 시각만 감지
- **내용 분석 금지** — 사용자 확인 없이 파일 내용 자동 분석 불가
- **자동 room 배정 금지** — pending 상태로 사용자 확인 대기
- **macOS sandbox 준수** — security-scoped 접근, entitlement 필요

---

## 감지 대상

```
확장자 허용 목록:
pdf, csv, xlsx, xls, docx, pptx, txt, md
png, jpg, jpeg, heic, zip
```

최소 파일 크기: 1KB 이상

---

## 흐름

```
사용자: "다운로드 폴더 감시 켜줘"
  ↓
DownloadsFolderWatcher.enable()
  ↓
(새 파일 감지)
  ↓
handleDetectedFile(at:) → LocalObservation 생성 (pending)
  ↓
FileIntakeEventCardView 표시
  → "이 방에서 분석" / "무시"
```

---

## macOS 권한

- 샌드박스: `com.apple.security.files.downloads.read-only` entitlement 필요
- 실제 FSEvents 구현: Mac local build phase에서 완성
- 현재: skeleton + policy 구현

---

## UI 안내 문구

- "다운로드된 파일을 발견했어요." → [이 방에서 분석] [무시]
- 권한 없을 때: "시스템 설정 → 개인 정보 보호에서 MyTeam의 파일 접근을 허용해 주세요."

## Round 247A-OBSERVE-RUNTIME 확인

- Downloads watcher default OFF 유지 (isEnabled = false)
- 사용자 명시 활성화 없이 자동 감시 없음
- RuntimeDiagnostics: downloadsWatcherSettingsDefaultOff 필드 추가
- ToolContractValidator: validateDownloadsWatcherDefaultOffUIPolicy 추가
