# Google Calendar OAuth QA

## 사전 조건
- Google Cloud Console Desktop OAuth client ID 준비
- MyTeam Settings > 비서 연결 > Google OAuth client ID 입력
- redirect mode: custom URL scheme
- scope: calendar.events.readonly

## 테스트
1. 설정 저장
2. Google Calendar 연결 클릭
3. 브라우저 / 인증 세션 표시 확인
4. 권한 승인
5. `myteam:/oauth2redirect/google` callback 복귀 확인
6. token exchange 성공 확인
7. Keychain token 저장 확인
8. 오늘 브리핑에 일정 표시 확인
9. 앱 재실행 후 연결 상태 유지 확인
10. 잘못된 client ID 오류 확인
11. 권한 거부 오류 확인

## 금지 확인
- Gmail scope 요청 없음
- calendar write scope 요청 없음
- token / code 로그 없음

## 기대 결과
- 연결되지 않았을 때는 `연결 필요` 또는 `Client ID 필요`
- 연결 중에는 `연결 중...`
- 실패 시에는 짧은 오류만 표시
- Daily Briefing은 실패해도 깨지지 않음
