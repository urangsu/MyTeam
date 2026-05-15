# Truthful Privacy Copy Policy

---

## Core Principle

MyTeam의 마케팅 메시지는 **강하게** 가되, 프라이버시 표현은 **절대 과장하면 안 됩니다**.

### Allowed Messaging
**강한 마케팅**: "내 컴퓨터 안의 AI 업무 팀", "회의록을 빠르게", "BYOK로 확장"

**정확한 프라이버시**: "로컬 중심이며, AI 기능은 사용자가 선택한 provider 기반"

### Forbidden Messaging
❌ "완전 로컬"
❌ "외부 서버 없음"
❌ "내 기기 안에서만 처리"
❌ "어떤 데이터도 외부로 나가지 않음"
❌ "100% 개인정보 보호"
❌ "서버 접근 불가"

---

## Allowed Copy

### Marketing (Strong)
- ✅ "내 컴퓨터 안의 AI 업무 팀"
- ✅ "회의록·체크리스트·보고서를 빠르게"
- ✅ "로컬 문서 기능은 API key 없이 시작"
- ✅ "BYOK (Bring Your Own Key)로 AI 확장"
- ✅ "생성된 문서는 내 Mac의 Workspace에 저장"
- ✅ "MyTeam 자체 서버에 파일을 저장하지 않음"
- ✅ "위험한 작업은 자동 실행하지 않음"

### Privacy (Truthful & Specific)
- ✅ "로컬 기능" (문서 템플릿, 파일 정리, 오늘 할 일)은 내 Mac에서만 처리
- ✅ "AI 기능" (문서 생성)을 사용할 때, 선택한 텍스트가 사용자가 연결한 API provider로 전송될 수 있음
- ✅ "MyTeam 자체 서버"에는 파일을 보관하지 않음
- ✅ "생성된 artifact"는 Workspace 폴더에 저장되므로 사용자가 언제든 삭제 가능
- ✅ "API key는 로컬 Keychain에만 저장"하고, diagnostic logs에는 포함하지 않음

### Transparency (Required)
- ✅ "AI 기능의 동작" — Claude API, OpenAI API 등 사용자가 선택한 provider로 동작
- ✅ "provider 비용" — 해당 provider의 요금 정책에 따름 (MyTeam 추가 요금 없음)
- ✅ "token/auth 보안" — API key/token/auth code는 로그에 저장하지 않음
- ✅ "user-selected files" — 사용자가 명시적으로 선택한 파일만 읽음
- ✅ "diagnostic redaction" — raw file content, API keys, tokens는 diagnostic에 포함하지 않음

---

## Data Flow Explanation

### Local-Only Features (API Key Not Required)
1. **문서 템플릿** (회의록, 체크리스트, 보고서 양식)
   - Location: 내 Mac의 MyTeam 앱
   - Data: 저장되지 않음 (실시간 생성)
   - External: ❌ 외부 전송 없음

2. **로컬 파일 정리** (텍스트, 마크다운, CSV 읽기)
   - Location: 내 Mac의 MyTeam 앱
   - Data: 읽기만, 저장 안 함 (처리 결과 제외)
   - External: ❌ 외부 전송 없음

3. **오늘 할 일 브리핑** (로컬 스케줄 확인)
   - Location: 내 Mac의 MyTeam 앱
   - Data: 로컬 스케줄 읽기만
   - External: ❌ 외부 전송 없음

### AI Features (API Key Required)
1. **회의록/체크리스트/보고서 생성** (AI 기반)
   - User Input: 사용자가 붙여넣은 텍스트 또는 파일 내용
   - Where Sent: 사용자가 연결한 API provider (Claude API, OpenAI API 등)
   - NOT Sent: MyTeam 자체 서버
   - MyTeam Role: 요청 중개만 (로그 저장 X)
   - Output: MyTeam에서 받은 응답 → 사용자 Workspace 저장

2. **파일 처리** (요약, 표로 변환 등)
   - User Input: 선택한 파일의 내용
   - Where Sent: 사용자가 연결한 API provider
   - NOT Sent: MyTeam 자체 서버
   - MyTeam Role: 요청 중개만
   - Output: Workspace 저장

### Saved Artifacts
- Location: `~/MyTeam/Workspace/`
- Ownership: 사용자 (언제든 삭제 가능)
- External: MyTeam 자체 서버에는 저장되지 않음
- Access: Finder에서 직접 접근 가능

---

## Copy by Context

### App Store Description
```
MyTeam은 macOS에서 문서 초안, 파일 정리, 오늘 할 일 브리핑을 도와주는 업무 보조 앱입니다.

로컬 문서 기능은 API key 없이 바로 시작할 수 있고, AI 기능은 사용자가 연결한 API provider를 통해 동작합니다. MyTeam은 자신의 서버에 파일을 저장하지 않으며, 생성된 문서는 내 Mac의 Workspace에 저장됩니다.
```

### In-App: First Launch (No API Key)
```
📱 로컬 기능부터 시작하세요
회의록 양식, 체크리스트, 파일 정리는 API key 없이도 사용할 수 있습니다.

AI 기능은 Claude, OpenAI 등의 API key를 연결해서 확장할 수 있습니다.

MyTeam 자체 서버에 파일을 저장하지 않으며, 생성된 문서는 내 Mac의 Workspace 폴더에 저장됩니다.
```

### In-App: Settings (API Key Connection)
```
🔐 API Key 설정
AI 기능 (회의록 생성, 문서 요약 등)을 사용하려면 API key를 연결하세요.

사용 가능한 provider:
- Claude (Anthropic)
- OpenAI
- Gemini (Google)
- Open Router

비용은 각 provider의 요금 정책에 따릅니다.

💡 안내: API key는 내 Mac의 Keychain에만 저장되며, MyTeam 서버에 전송되지 않습니다.
```

### Privacy Policy (Key Sections)
```
## 데이터 저장
- Local-only 기능: 내 Mac의 MyTeam 폴더에만 저장
- 생성된 artifact: Workspace 폴더 (사용자가 관리)
- MyTeam 자체 서버: 파일 저장 없음

## 외부 API 전송
AI 기능을 사용할 때, 선택한 텍스트/파일이 사용자가 연결한 API provider로 전송될 수 있습니다.
예: Claude API, OpenAI API 등

전송되는 정보:
- 사용자가 입력한 텍스트/파일 내용
- 기본 메타데이터 (timestamp 등)

전송되지 않는 정보:
- 다른 사용자의 데이터
- API key (로컬 Keychain에만 저장)
- diagnostic logs에는 raw data 포함 X

## 삭제 권리
생성된 모든 artifact는 Finder에서 직접 삭제할 수 있으며, 삭제 즉시 MyTeam에서도 제거됩니다.
```

### Blog Post Example: "BYOK AI 앱이 뭔지 쉽게 설명해드립니다"
```
## BYOK = Bring Your Own Key

BYOK AI 앱은 "앱이 자신의 서버를 운영하지 않고, 사용자가 선택한 API provider를 사용"하는 방식입니다.

### MyTeam의 경우

**로컬에서 처리** (API key 없어도)
- 회의록/체크리스트 양식
- 파일 정리 (텍스트 마크다운 CSV)
- 오늘 할 일 브리핑

**외부 API 사용** (API key 필요)
- 회의록 생성 (LLM 기반)
- 문서 생성 (LLM 기반)
- 파일 요약/변환 (LLM 기반)

API key를 연결하면, MyTeam이 사용자 선택 provider (Claude, OpenAI 등)로 요청을 보냅니다.
비용은 해당 provider 요금.

### 왜 BYOK인가?

1. **신뢰** — MyTeam이 데이터를 보관하지 않음
2. **선택** — 사용자가 원하는 provider 사용 가능
3. **투명성** — API 사용 비용이 명확함
4. **보안** — API key는 로컬에만 저장
```

---

## Forbidden Copy Examples

### ❌ "외부 서버 없음"
**Why forbidden**: 부정확. AI 기능 사용 시 외부 API provider로 전송됨.

**Fix**: "MyTeam 자체 서버에 파일을 저장하지 않습니다. AI 기능은 사용자가 선택한 provider를 통해 동작합니다."

### ❌ "완전 로컬"
**Why forbidden**: 부정확. AI 기능은 로컬이 아님.

**Fix**: "로컬 기능은 내 Mac에서 처리됩니다. AI 기능은 사용자가 연결한 provider로 확장 가능합니다."

### ❌ "내 기기 안에서만 처리"
**Why forbidden**: 부정확. AI 기능의 경우 외부 전송.

**Fix**: "로컬 기능은 내 기기에서만, AI 기능은 사용자가 선택한 provider에서 처리됩니다."

### ❌ "어떤 데이터도 외부로 나가지 않음"
**Why forbidden**: 거짓. AI 사용 시 데이터 전송.

**Fix**: "로컬 기능은 외부로 나가지 않습니다. AI 기능 사용 시 선택한 텍스트가 API provider로 전송될 수 있습니다."

---

## Compliance Checklist

### App Store Guideline Compliance
- ✅ "외부 서버 없음"이 아니라 "자체 서버에 저장 안 함"
- ✅ AI provider 전송 명시
- ✅ "완전 로컬"이 아니라 "로컬 우선"
- ✅ API key 보안 설명
- ✅ 사용자 데이터 삭제 권리 명시

### GDPR/PIPA Compliance
- ✅ 데이터 처리 위치 명확
- ✅ third-party API provider 명시
- ✅ 사용자 동의 프로세스 명확
- ✅ 데이터 삭제 요청 프로세스 명확

### Korean Privacy Law (개인정보보호법)
- ✅ 개인정보 수집 목적 명시
- ✅ 제3자 제공 명시
- ✅ 보유 기간 명시
- ✅ 조회/정정/삭제/처리정지 권리 명시

---

## Enforcement

### Content Review Checklist (before publishing)
Before any marketing copy, blog, email:

- [ ] "외부 서버 없음" 포함? → 제거
- [ ] "완전 로컬" 포함? → "로컬 중심"으로 변경
- [ ] "내 기기 안에서만" 포함? → "로컬 기능은 로컬에서" 추가
- [ ] "API provider 전송" 명시했나? → 명시
- [ ] "MyTeam 자체 서버 미저장" 명시했나? → 명시

### Code Review
Before merging privacy-related copy changes:

- [ ] Privacy policy updated?
- [ ] In-app copy aligned with policy?
- [ ] App Store description aligned?
- [ ] diagnostics redaction rules followed?

### Marketing Review
All marketing materials (blog, social, email) quarterly:

- [ ] 과장 표현 검토
- [ ] API provider 투명성 검토
- [ ] local-only vs. AI features 명확히 구분
