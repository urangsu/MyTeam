# App Store Metadata Draft

## App Name
MyTeam

## Subtitle
로컬 파일과 문서를 도와주는 AI 업무 팀

## Short Description
MyTeam은 문서 초안, 파일 정리, 오늘 할 일 브리핑을 로컬 중심으로 도와주는 macOS 업무 보조 앱입니다.

## Keywords
AI, 문서, 파일정리, 업무, 브리핑, 생산성, macOS

## What It Does

### Core Capabilities
- **문서 초안 생성**: 회의록, 체크리스트, 보고서 등 다양한 템플릿 기반 문서 작성
- **파일 정리**: 로컬 파일을 읽고 분석하여 정리 및 요약
- **오늘 할 일 브리핑**: 로컬 스케줄과 작업 목록 확인
- **최근 문서 재사용**: 이전에 만든 문서를 빠르게 접근하고 수정
- **안전한 로컬 처리**: 개인 파일은 로컬에서만 처리되며 외부로 전송되지 않음
- **AI 기능 선택**: 로컬 기능만으로도 사용 가능하며, API 키 연결 시 AI 기능 활성화

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

### Data Protection
- 사용자 파일은 로컬 디바이스에서만 처리
- API 요청 시 필요한 최소 정보만 전송
- 민감한 데이터는 로컬 저장소에 암호화 저장 불가 정책

### Transparency
- 앱이 액세스하는 파일을 사용자가 명시적으로 선택
- 외부 연결(Calendar, Gmail)은 명확한 권한 요청
- 자동 실행 기능은 사용자에게 명확히 표시

## System Requirements
- macOS 12.0 or later
- Apple Silicon or Intel (Universal Binary)

## Version Notes
- Version 1.0: Initial release with local document, file management, and AI assistance
- Focus on reliability and user trust
- Sandbox-compliant for App Store distribution
