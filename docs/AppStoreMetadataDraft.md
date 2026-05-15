# App Store Metadata Draft

## App Name
MyTeam - AI 업무 팀

## Subtitle
회의록·체크리스트·보고서를 빠르게

## Short Description
내 컴퓨터 안의 AI 업무 팀. MyTeam은 회의록, 체크리스트, 보고서 초안을 빠르게 만들고 파일을 정리하는 macOS 업무 보조 앱입니다.

로컬 문서 기능은 API key 없이 바로 시작할 수 있고, AI 기능은 사용자가 연결한 API provider를 통해 동작합니다.

## Keywords
AI어시스턴트, 회의록, 보고서, 업무자동화, macOS AI, 문서생성, 할일정리, AI도구, 업무도우미, 생산성, 로컬기능, BYOK, 체크리스트, 문서요약, AI팀

## What It Does

### Core Capabilities
- **문서 초안 생성**: 회의록, 체크리스트, 보고서 등 다양한 템플릿 기반 문서 작성
- **파일 정리**: 로컬 파일을 읽고 분석하여 정리 및 요약
- **오늘 할 일 브리핑**: 로컬 스케줄과 작업 목록 확인
- **최근 문서 재사용**: 이전에 만든 문서를 빠르게 접근하고 수정
- **로컬 우선 처리**: 로컬 기능 (문서 템플릿, 파일 정리, 오늘 할 일)은 API key 없이 내 Mac에서만 처리
- **AI 기능 선택**: API 키 연결 시 AI 기능 활성화. 이 경우 선택한 텍스트가 사용자가 연결한 API provider로 전송될 수 있음

### Future Features (Preparing)
- Google Calendar 읽기 연결 (준비 중)
- Gmail 메타데이터 조회 (향후 지원)
- 추가 connector 지원

## What It Does NOT Do

### Explicitly Restricted
- 메일을 자동 발송하지 않음 (사용자 명시 승인 필수)
- 일정을 자동 생성/수정하지 않음
- 파일을 자동 삭제하지 않음
- 외부 서버에 파일을 자동 업로드하지 않음
- 사용자 모르게 파일에 접근하지 않음

### Not Supported
- 웹 브라우징 자동화
- 자동 메일 분류
- 클라우드 자동 동기화
- 외부 API 자동 호출

## Use Cases

### For Administrative Staff
- 회의록 자동 작성
- 서류 정리 및 요약
- 일일 업무 리스트 관리

### For Content Creators
- 콘텐츠 아이디어 정리
- 원고 초안 작성
- 피드백 정리

### For Business Owners
- 사업 계획 작성
- 체크리스트 관리
- 회의 정리 및 액션 아이템 추적

### For Any Knowledge Worker
- 문서 초안 작성
- 정보 정리
- 일일 계획 수립

## Privacy & Security

### Data Flow
- **로컬 기능** (API key 불필요): 모든 처리가 내 Mac에서만 진행. MyTeam 자체 서버에 저장 안 함
- **AI 기능** (API key 필요): 선택한 텍스트/파일이 사용자가 연결한 API provider로 전송될 수 있음 (예: Claude API, OpenAI API)
- **생성된 문서**: MyTeam Workspace 폴더에 저장. 사용자가 언제든 삭제 가능

### Security
- API key는 로컬 Keychain에만 저장. 로그에는 포함되지 않음
- 사용자가 명시적으로 선택한 파일만 읽음
- 자동 실행 기능 없음 (메일 발송, 일정 생성, 파일 삭제 등)
- 모든 위험 작업은 사용자 승인 필수

### Transparency
- 앱이 액세스하는 파일을 사용자가 명시적으로 선택
- AI 기능 사용 시 API provider 전송 명시
- MyTeam 자체 서버에 파일을 저장하지 않음

## System Requirements
- macOS 12.0 or later
- Apple Silicon or Intel (Universal Binary)

## Version Notes
- Version 1.0: Initial release with local document, file management, and AI assistance
- Focus on reliability and user trust
- Sandbox-compliant for App Store distribution
