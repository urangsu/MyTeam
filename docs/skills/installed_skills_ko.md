# Codex Installed Skills Korean Catalog

생성일: 2026-06-03

이 문서는 설치된 `SKILL.md`를 한국어로 빠르게 훑기 위한 카탈로그입니다. 원본 skill 파일은 라우팅과 업데이트 안정성을 위해 수정하지 않습니다.

## 운영 규칙

- 이 문서는 조회용입니다. 실제 skill 라우팅은 원본 `SKILL.md`의 `name`, `description`, 경로, frontmatter를 사용합니다.
- skill 설명을 한국어로 바꾸고 싶어도 원본 파일을 직접 덮어쓰지 않습니다.
- 영어 원문 설명은 라우팅 키워드 보존을 위해 함께 남깁니다.
- MyTeam 작업에서는 AGENTS.md의 P0/Structural/Product 규칙이 이 카탈로그보다 우선합니다.

## 법률 MCP 재구성 방향

korean-law-mcp를 그대로 Node MCP 서버로 App Store 런타임에 번들링하는 것은 비추천입니다. 하지만 korean-law-mcp가 제공하는 기능과 구조를 MyTeam Skill Package 표준으로 재구성하는 것은 적극 추진 대상입니다.

우선순위:

- P0: 법령 검색, 조문 조회, 인용 검증
- P1: 판례, 행정규칙, 해석례
- P2: 시점 비교, 영향 그래프

MyTeam 방식:

- `ExternalProvider.koreanLaw`를 추가할 예정입니다.
- required credential은 `lawOC`입니다.
- 자격 증명은 `SecureCredentialStore`를 통해 Keychain에 저장합니다.
- 앱 런타임은 `KoreanLawDirectConnector.swift` 같은 Swift `directREST` 경로로 공식 법령 API를 호출하는 방향이 맞습니다.
- 결과 UI는 `LegalResearchCard` 계열 계약으로 정리하고, 법령명, 조문, 시행일, 공식 출처를 필수로 표시해야 합니다.
- 법률 답변은 검증 없이 `verified`로 처리하면 안 되고, 변호사 자문처럼 단정해서도 안 됩니다.

선택형 확장:

- `externalMCP` 연결은 나중에 power-user 또는 direct-download 모드에서 선택형으로 검토할 수 있습니다.
- 다만 런타임 연결 전에는 사용 가능으로 표시하지 않습니다.

## 요약

- 발견된 `SKILL.md`: 234개
- JSON 카탈로그: `docs/skills/installed_skills_ko.json`

## 스킬 목록

### gstack

- 경로: `/Users/su/.agents/skills/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, MCP, node
- 원문 description: |

### agent-browser

- 경로: `/Users/su/.agents/skills/agent-browser/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, GitHub, Playwright, Vercel, vercel
- 원문 description: Automates browser interactions for web testing, form filling, screenshots, and data extraction. Use when the user needs to navigate websites, interact with web pages, fill forms, take screenshots, test web applications, or extract information from web pages.

### autoplan

- 경로: `/Users/su/.agents/skills/autoplan/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, MCP, npm, rg
- 원문 description: |

### benchmark

- 경로: `/Users/su/.agents/skills/benchmark/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git
- 원문 description: |

### browse

- 경로: `/Users/su/.agents/skills/browse/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, git, node
- 원문 description: |

### canary

- 경로: `/Users/su/.agents/skills/canary/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub
- 원문 description: |

### careful

- 경로: `/Users/su/.agents/skills/careful/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 설치된 작업 보조 스킬입니다. 원문 설명을 기준으로 특정 상황에서 Codex 행동을 좁히고 품질 기준을 올리는 데 사용합니다.
- 주요 사용 시점: 사용자 요청이나 원문 description이 이 스킬의 목적과 직접 맞을 때 사용합니다.
- 금지사항/주의사항: 원본 SKILL.md의 name, description, path, frontmatter는 라우팅 안정성을 위해 수정하지 않습니다.
- 명령어/도구 의존성: git, node
- 원문 description: |

### checkpoint

- 경로: `/Users/su/.agents/skills/checkpoint/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, git
- 원문 description: |

### codex

- 경로: `/Users/su/.agents/skills/codex/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, npm, python, rg
- 원문 description: |

### open-gstack-browser

- 경로: `/Users/su/.agents/skills/connect-chrome/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, git, Playwright, rg
- 원문 description: |

### cso

- 경로: `/Users/su/.agents/skills/cso/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, node, npm
- 원문 description: |

### design-consultation

- 경로: `/Users/su/.agents/skills/design-consultation/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, rg
- 원문 description: |

### design-html

- 경로: `/Users/su/.agents/skills/design-html/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, npm, python
- 원문 description: |

### design-review

- 경로: `/Users/su/.agents/skills/design-review/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, node, npm, Playwright, playwright, python
- 원문 description: |

### design-shotgun

- 경로: `/Users/su/.agents/skills/design-shotgun/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git
- 원문 description: |

### dev-browser

- 경로: `/Users/su/.agents/skills/dev-browser/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, GitHub, npm, npx, Playwright
- 원문 description: Browser automation with persistent page state. Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include "go to [url]", "click on", "fill out the form", "take a screenshot", "scrape", "automate", "test the website", "log into", or any browser interaction request.

### devex-review

- 경로: `/Users/su/.agents/skills/devex-review/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, rg, Vercel
- 원문 description: |

### document-release

- 경로: `/Users/su/.agents/skills/document-release/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, node, python
- 원문 description: |

### freeze

- 경로: `/Users/su/.agents/skills/freeze/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: git
- 원문 description: |

### frontend-ui-ux

- 경로: `/Users/su/.agents/skills/frontend-ui-ux/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: git
- 원문 description: Designer-turned-developer who crafts stunning UI/UX even without design mockups

### git-master

- 경로: `/Users/su/.agents/skills/git-master/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: git 작업을 원자적이고 안전하게 처리하는 스킬입니다.
- 주요 사용 시점: commit, push, rebase, blame, history 탐색 때 사용합니다.
- 금지사항/주의사항: force push나 destructive 명령은 신중하게 다룹니다.
- 명령어/도구 의존성: browse, browser, git
- 원문 description: MUST USE for ANY git operations. Atomic commits, rebase/squash, history search (blame, bisect, log -S). STRONGLY RECOMMENDED: Use with task(category='quick', load_skills=['git-master'], ...) to save context. Triggers: 'commit', 'rebase', 'squash', 'who wrote', 'when was X added', 'find the commit that'.

### graphifyy

- 경로: `/Users/su/.agents/skills/graphifyy/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: Build and query knowledge graphs for the workspace using graphifyy.

### gstack-upgrade

- 경로: `/Users/su/.agents/skills/gstack-upgrade/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: git, GitHub
- 원문 description: |

### guard

- 경로: `/Users/su/.agents/skills/guard/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: git
- 원문 description: |

### health

- 경로: `/Users/su/.agents/skills/health/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, git, node, npx
- 원문 description: |

### investigate

- 경로: `/Users/su/.agents/skills/investigate/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: browse, browser, gh, git
- 원문 description: |

### land-and-deploy

- 경로: `/Users/su/.agents/skills/land-and-deploy/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, rg, Vercel, vercel
- 원문 description: |

### learn

- 경로: `/Users/su/.agents/skills/learn/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: browse, browser, git
- 원문 description: |

### office-hours

- 경로: `/Users/su/.agents/skills/office-hours/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, rg
- 원문 description: |

### open-gstack-browser

- 경로: `/Users/su/.agents/skills/open-gstack-browser/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, git, Playwright, rg
- 원문 description: |

### plan-ceo-review

- 경로: `/Users/su/.agents/skills/plan-ceo-review/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, node, npm, rg
- 원문 description: |

### plan-design-review

- 경로: `/Users/su/.agents/skills/plan-design-review/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, rg
- 원문 description: |

### plan-devex-review

- 경로: `/Users/su/.agents/skills/plan-devex-review/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, npm, npx, rg, Vercel
- 원문 description: |

### plan-eng-review

- 경로: `/Users/su/.agents/skills/plan-eng-review/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 엔지니어링 매니저 관점에서 아키텍처와 실행 계획을 검토하는 스킬입니다.
- 주요 사용 시점: 구조 변경, 데이터 흐름, 테스트 전략을 잠그기 전에 사용합니다.
- 금지사항/주의사항: 구현보다 먼저 리스크와 엣지 케이스를 드러내야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, node, Playwright, playwright, python, rg
- 원문 description: |

### qa-only

- 경로: `/Users/su/.agents/skills/qa-only/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, rg
- 원문 description: |

### qa

- 경로: `/Users/su/.agents/skills/qa/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, node, npm, Playwright, playwright, python, rg
- 원문 description: |

### retro

- 경로: `/Users/su/.agents/skills/retro/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, node
- 원문 description: |

### review

- 경로: `/Users/su/.agents/skills/review/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, node, npm, python, rg
- 원문 description: |

### setup-browser-cookies

- 경로: `/Users/su/.agents/skills/setup-browser-cookies/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, git, GitHub, Playwright
- 원문 description: |

### setup-deploy

- 경로: `/Users/su/.agents/skills/setup-deploy/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, Vercel, vercel
- 원문 description: |

### ship

- 경로: `/Users/su/.agents/skills/ship/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, node, npm, Playwright, playwright, python, rg
- 원문 description: |

### unfreeze

- 경로: `/Users/su/.agents/skills/unfreeze/SKILL.md`
- 분류: G-Stack/Agents skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: git
- 원문 description: |

### access

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord/skills/access/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: Manage Discord channel access — approve pairings, edit allowlists, set DM/group policy. Use when the user asks to pair, approve someone, check who's allowed, or change policy for the Discord channel.

### configure

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/discord/skills/configure/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: gh
- 원문 description: Set up the Discord channel — save the bot token and review access policy. Use when the user pastes a Discord bot token, asks to configure Discord, asks "how do I set this up" or "who can reach me," or wants to check channel status.

### access

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/imessage/skills/access/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: Manage iMessage channel access — approve pairings, edit allowlists, set DM/group policy. Use when the user asks to pair, approve someone, check who's allowed, or change policy for the iMessage channel.

### configure

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/imessage/skills/configure/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: gh
- 원문 description: Check iMessage channel setup and review access policy. Use when the user asks to configure iMessage, asks "how do I set this up" or "who can reach me," or wants to know why texts aren't reaching the assistant.

### access

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/skills/access/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: Manage Telegram channel access — approve pairings, edit allowlists, set DM/group policy. Use when the user asks to pair, approve someone, check who's allowed, or change policy for the Telegram channel.

### configure

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/skills/configure/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: gh
- 원문 description: Set up the Telegram channel — save the bot token and review access policy. Use when the user pastes a Telegram bot token, asks to configure Telegram, asks "how do I set this up" or "who can reach me," or wants to check channel status.

### claude-automation-recommender

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/claude-code-setup/skills/claude-automation-recommender/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, git, GitHub, MCP, npm, Playwright
- 원문 description: Analyze a codebase and recommend Claude Code automations (hooks, subagents, skills, plugins, MCP servers). Use when user asks for automation recommendations, wants to optimize their Claude Code setup, mentions improving Claude Code workflows, asks how to first set up Claude Code for a project, or wants to know what Claude Code features they should use.

### claude-md-improver

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/claude-md-management/skills/claude-md-improver/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 설치된 작업 보조 스킬입니다. 원문 설명을 기준으로 특정 상황에서 Codex 행동을 좁히고 품질 기준을 올리는 데 사용합니다.
- 주요 사용 시점: 사용자 요청이나 원문 description이 이 스킬의 목적과 직접 맞을 때 사용합니다.
- 금지사항/주의사항: 원본 SKILL.md의 name, description, path, frontmatter는 라우팅 안정성을 위해 수정하지 않습니다.
- 명령어/도구 의존성: gh, npm
- 원문 description: Audit and improve CLAUDE.md files in repositories. Use when user asks to check, audit, update, improve, or fix CLAUDE.md files. Scans for all CLAUDE.md files, evaluates quality against templates, outputs quality report, then makes targeted updates. Also use when the user mentions "CLAUDE.md maintenance" or "project memory optimization".

### example-command

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/example-plugin/skills/example-command/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: An example user-invoked skill that demonstrates frontmatter options and the skills/<name>/SKILL.md layout

### example-skill

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/example-plugin/skills/example-skill/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: This skill should be used when the user asks to "demonstrate skills", "show skill format", "create a skill template", or discusses skill development patterns. Provides a reference template for creating Claude Code plugin skills.

### frontend-design

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/frontend-design/skills/frontend-design/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh
- 원문 description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.

### writing-hookify-rules

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/hookify/skills/writing-rules/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, git, node, python
- 원문 description: This skill should be used when the user asks to "create a hookify rule", "write a hook rule", "configure hookify", "add a hookify rule", or needs guidance on hookify rule syntax and patterns.

### math-olympiad

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/math-olympiad/skills/math-olympiad/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: gh
- 원문 description: Solve competition math problems (IMO, Putnam, USAMO, AIME) with adversarial verification that catches the errors self-verification misses. Activates when asked to 'solve this IMO problem', 'prove this olympiad inequality', 'verify this competition proof', 'find a counterexample', 'is this proof correct', or for any problem with 'IMO', 'Putnam', 'USAMO', 'olympiad', or 'competition math' in it. Uses pure reasoning (no tools) — then a fresh-context adversarial verifier attacks the proof using specific failure patterns, not generic 'check logic'. Outputs calibrated confidence — will say 'no confident solution' rather than bluff. If LaTeX is available, produces a clean PDF after verification passes.

### build-mcp-app

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/mcp-server-dev/skills/build-mcp-app/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, MCP, node, npm, npx
- 원문 description: This skill should be used when the user wants to build an "MCP app", add "interactive UI" or "widgets" to an MCP server, "render components in chat", build "MCP UI resources", make a tool that shows a "form", "picker", "dashboard" or "confirmation dialog" inline in the conversation, or mentions "apps SDK" in the context of MCP. Use AFTER the build-mcp-server skill has settled the deployment model, or when the user already knows they want UI widgets.

### build-mcp-server

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/mcp-server-dev/skills/build-mcp-server/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, MCP, npx
- 원문 description: This skill should be used when the user asks to "build an MCP server", "create an MCP", "make an MCP integration", "wrap an API for Claude", "expose tools to Claude", "make an MCP app", or discusses building something with the Model Context Protocol. It is the entry point for MCP server development — it interrogates the user about their use case, determines the right deployment model (remote HTTP, MCPB, local stdio), picks a tool-design pattern, and hands off to specialized skills.

### build-mcpb

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/mcp-server-dev/skills/build-mcpb/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, GitHub, MCP, node, npm, npx, python
- 원문 description: This skill should be used when the user wants to "package an MCP server", "bundle an MCP", "make an MCPB", "ship a local MCP server", "distribute a local MCP", discusses ".mcpb files", mentions bundling a Node or Python runtime with their MCP server, or needs an MCP server that interacts with the local filesystem, desktop apps, or OS and must be installable without the user having Node/Python set up.

### playground

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/playground/skills/playground/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, gh, git
- 원문 description: Creates interactive HTML playgrounds — self-contained single-file explorers that let users configure something visually through controls, see a live preview, and copy out a prompt. Use when the user asks to make a playground, explorer, or interactive tool for a topic.

### agent-development

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/agent-development/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: This skill should be used when the user asks to "create an agent", "add an agent", "write a subagent", "agent frontmatter", "when to use description", "agent examples", "agent tools", "agent colors", "autonomous agent", or needs guidance on agent structure, system prompts, triggering conditions, or agent development best practices for Claude Code plugins.

### command-development

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/command-development/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, git, node, npm
- 원문 description: This skill should be used when the user asks to "create a slash command", "add a command", "write a custom command", "define command arguments", "use command frontmatter", "organize commands", "create command with file references", "interactive command", "use AskUserQuestion in command", or needs guidance on slash command structure, YAML frontmatter fields, dynamic arguments, bash execution in commands, user interaction patterns, or command development best practices for Claude Code.

### hook-development

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/hook-development/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: MCP, node
- 원문 description: This skill should be used when the user asks to "create a hook", "add a PreToolUse/PostToolUse/Stop hook", "validate tool use", "implement prompt-based hooks", "use ${CLAUDE_PLUGIN_ROOT}", "set up event-driven automation", "block dangerous commands", or mentions hook events (PreToolUse, PostToolUse, Stop, SubagentStop, SessionStart, SessionEnd, UserPromptSubmit, PreCompact, Notification). Provides comprehensive guidance for creating and implementing Claude Code plugin hooks with focus on advanced prompt-based hooks API.

### mcp-integration

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/mcp-integration/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, GitHub, MCP, npx, python
- 원문 description: This skill should be used when the user asks to "add MCP server", "integrate MCP", "configure MCP in plugin", "use .mcp.json", "set up Model Context Protocol", "connect external service", mentions "${CLAUDE_PLUGIN_ROOT} with MCP", or discusses MCP server types (SSE, stdio, HTTP, WebSocket). Provides comprehensive guidance for integrating Model Context Protocol servers into Claude Code plugins for external tool and service integration.

### plugin-settings

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/plugin-settings/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: This skill should be used when the user asks about "plugin settings", "store plugin configuration", "user-configurable plugin", ".local.md files", "plugin state files", "read YAML frontmatter", "per-project plugin settings", or wants to make plugin behavior configurable. Documents the .claude/plugin-name.local.md pattern for storing plugin-specific configuration with YAML frontmatter and markdown content.

### plugin-structure

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/plugin-structure/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, MCP, node, npm
- 원문 description: This skill should be used when the user asks to "create a plugin", "scaffold a plugin", "understand plugin structure", "organize plugin components", "set up plugin.json", "use ${CLAUDE_PLUGIN_ROOT}", "add commands/agents/skills/hooks", "configure auto-discovery", or needs guidance on plugin directory layout, manifest configuration, component organization, file naming conventions, or Claude Code plugin architecture best practices.

### skill-development

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/skill-development/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: MCP
- 원문 description: This skill should be used when the user wants to "create a skill", "add a skill to plugin", "write a new skill", "improve skill description", "organize skill content", or needs guidance on skill structure, progressive disclosure, or skill development best practices for Claude Code plugins.

### skill-creator

- 경로: `/Users/su/.claude/plugins/marketplaces/claude-plugins-official/plugins/skill-creator/skills/skill-creator/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 새 Codex skill을 설계하고 만드는 스킬입니다.
- 주요 사용 시점: 새 skill 생성 또는 기존 skill 업데이트 요청에 사용합니다.
- 금지사항/주의사항: frontmatter와 routing description을 훼손하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, MCP, npm, python
- 원문 description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, update or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.

### graphify

- 경로: `/Users/su/.claude/skills/graphify/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, MCP, node, python, swift
- 원문 description: any input (code, docs, papers, images) - knowledge graph - clustered communities - HTML + JSON + audit report

### gstack

- 경로: `/Users/su/.claude/skills/gstack/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, MCP, node, Playwright, playwright, rg
- 원문 description: |

### autoplan

- 경로: `/Users/su/.claude/skills/gstack/autoplan/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, npm, rg
- 원문 description: |

### benchmark-models

- 경로: `/Users/su/.claude/skills/gstack/benchmark-models/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP
- 원문 description: |

### benchmark

- 경로: `/Users/su/.claude/skills/gstack/benchmark/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP
- 원문 description: |

### browse

- 경로: `/Users/su/.claude/skills/gstack/browse/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, MCP, node, Playwright, playwright, rg
- 원문 description: |

### hackernews-frontpage

- 경로: `/Users/su/.claude/skills/gstack/browser-skills/hackernews-frontpage/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser
- 원문 description: Scrape the Hacker News front page (titles, points, comment counts).

### canary

- 경로: `/Users/su/.claude/skills/gstack/canary/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP
- 원문 description: |

### careful

- 경로: `/Users/su/.claude/skills/gstack/careful/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 설치된 작업 보조 스킬입니다. 원문 설명을 기준으로 특정 상황에서 Codex 행동을 좁히고 품질 기준을 올리는 데 사용합니다.
- 주요 사용 시점: 사용자 요청이나 원문 description이 이 스킬의 목적과 직접 맞을 때 사용합니다.
- 금지사항/주의사항: 원본 SKILL.md의 name, description, path, frontmatter는 라우팅 안정성을 위해 수정하지 않습니다.
- 명령어/도구 의존성: git, node
- 원문 description: |

### codex

- 경로: `/Users/su/.claude/skills/gstack/codex/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, npm, python, rg
- 원문 description: |

### context-restore

- 경로: `/Users/su/.claude/skills/gstack/context-restore/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 설치된 작업 보조 스킬입니다. 원문 설명을 기준으로 특정 상황에서 Codex 행동을 좁히고 품질 기준을 올리는 데 사용합니다.
- 주요 사용 시점: 사용자 요청이나 원문 description이 이 스킬의 목적과 직접 맞을 때 사용합니다.
- 금지사항/주의사항: 원본 SKILL.md의 name, description, path, frontmatter는 라우팅 안정성을 위해 수정하지 않습니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP
- 원문 description: |

### context-save

- 경로: `/Users/su/.claude/skills/gstack/context-save/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP
- 원문 description: |

### cso

- 경로: `/Users/su/.claude/skills/gstack/cso/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP, node, npm
- 원문 description: |

### design-consultation

- 경로: `/Users/su/.claude/skills/gstack/design-consultation/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, rg
- 원문 description: |

### design-html

- 경로: `/Users/su/.claude/skills/gstack/design-html/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, npm, python
- 원문 description: |

### design-review

- 경로: `/Users/su/.claude/skills/gstack/design-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, MCP, node, npm, Playwright, playwright
- 원문 description: |

### design-shotgun

- 경로: `/Users/su/.claude/skills/gstack/design-shotgun/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP
- 원문 description: |

### devex-review

- 경로: `/Users/su/.claude/skills/gstack/devex-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP, rg, Vercel
- 원문 description: |

### document-generate

- 경로: `/Users/su/.claude/skills/gstack/document-generate/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, node
- 원문 description: |

### document-release

- 경로: `/Users/su/.claude/skills/gstack/document-release/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, node, python
- 원문 description: |

### freeze

- 경로: `/Users/su/.claude/skills/gstack/freeze/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: git
- 원문 description: |

### gstack-upgrade

- 경로: `/Users/su/.claude/skills/gstack/gstack-upgrade/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: git, GitHub
- 원문 description: |

### guard

- 경로: `/Users/su/.claude/skills/gstack/guard/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: git
- 원문 description: |

### health

- 경로: `/Users/su/.claude/skills/gstack/health/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, node, npx
- 원문 description: |

### investigate

- 경로: `/Users/su/.claude/skills/gstack/investigate/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, MCP
- 원문 description: |

### ios-clean

- 경로: `/Users/su/.claude/skills/gstack/ios-clean/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, rg, swift, xcodebuild
- 원문 description: |

### ios-design-review

- 경로: `/Users/su/.claude/skills/gstack/ios-design-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, MCP, rg
- 원문 description: |

### ios-fix

- 경로: `/Users/su/.claude/skills/gstack/ios-fix/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, node, rg, swift, xcodebuild
- 원문 description: |

### ios-qa

- 경로: `/Users/su/.claude/skills/gstack/ios-qa/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP, python, rg, swift, xcodebuild
- 원문 description: |

### ios-sync

- 경로: `/Users/su/.claude/skills/gstack/ios-sync/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, rg, swift, xcodebuild
- 원문 description: |

### land-and-deploy

- 경로: `/Users/su/.claude/skills/gstack/land-and-deploy/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP, rg, Vercel, vercel
- 원문 description: |

### landing-report

- 경로: `/Users/su/.claude/skills/gstack/landing-report/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, rg
- 원문 description: |

### learn

- 경로: `/Users/su/.claude/skills/gstack/learn/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP
- 원문 description: |

### make-pdf

- 경로: `/Users/su/.claude/skills/gstack/make-pdf/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 문서, 발표자료, 스프레드시트 산출물을 만들거나 검토하는 스킬입니다.
- 주요 사용 시점: 문서 작성, PPT/PDF/XLSX 생성, 시각 렌더 검증 때 사용합니다.
- 금지사항/주의사항: 렌더링과 실제 파일 결과물을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP
- 원문 description: |

### office-hours

- 경로: `/Users/su/.claude/skills/gstack/office-hours/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, rg
- 원문 description: |

### open-gstack-browser

- 경로: `/Users/su/.claude/skills/gstack/open-gstack-browser/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, MCP, Playwright, rg
- 원문 description: |

### gstack-openclaw-ceo-review

- 경로: `/Users/su/.claude/skills/gstack/openclaw/skills/gstack-openclaw-ceo-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: gh, node
- 원문 description: Use when asked to review a plan, challenge a proposal, run a CEO review, poke holes in an approach, think bigger about scope, or decide whether to expand or reduce the plan.

### gstack-openclaw-investigate

- 경로: `/Users/su/.claude/skills/gstack/openclaw/skills/gstack-openclaw-investigate/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 설치된 작업 보조 스킬입니다. 원문 설명을 기준으로 특정 상황에서 Codex 행동을 좁히고 품질 기준을 올리는 데 사용합니다.
- 주요 사용 시점: 사용자 요청이나 원문 description이 이 스킬의 목적과 직접 맞을 때 사용합니다.
- 금지사항/주의사항: 원본 SKILL.md의 name, description, path, frontmatter는 라우팅 안정성을 위해 수정하지 않습니다.
- 명령어/도구 의존성: browse, browser, gh, git
- 원문 description: Use when asked to debug, fix a bug, investigate an error, or do root cause analysis, and when users report errors, stack traces, unexpected behavior, or say something stopped working.

### gstack-openclaw-office-hours

- 경로: `/Users/su/.claude/skills/gstack/openclaw/skills/gstack-openclaw-office-hours/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, git
- 원문 description: Use when asked to brainstorm, evaluate whether an idea is worth building, run office hours, or think through a new product idea or design direction before any code is written.

### gstack-openclaw-retro

- 경로: `/Users/su/.claude/skills/gstack/openclaw/skills/gstack-openclaw-retro/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, git, node
- 원문 description: Weekly engineering retrospective. Analyzes commit history, work patterns, and code quality metrics with persistent history and trend tracking. Team-aware with per-person contributions, praise, and growth areas. Use when asked for weekly retro, what shipped this week, or engineering retrospective.

### pair-agent

- 경로: `/Users/su/.claude/skills/gstack/pair-agent/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, rg
- 원문 description: |

### plan-ceo-review

- 경로: `/Users/su/.claude/skills/gstack/plan-ceo-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, node, npm, rg
- 원문 description: |

### plan-design-review

- 경로: `/Users/su/.claude/skills/gstack/plan-design-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, git, GitHub, MCP, rg
- 원문 description: |

### plan-devex-review

- 경로: `/Users/su/.claude/skills/gstack/plan-devex-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, npm, npx, rg, Vercel
- 원문 description: |

### plan-eng-review

- 경로: `/Users/su/.claude/skills/gstack/plan-eng-review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 엔지니어링 매니저 관점에서 아키텍처와 실행 계획을 검토하는 스킬입니다.
- 주요 사용 시점: 구조 변경, 데이터 흐름, 테스트 전략을 잠그기 전에 사용합니다.
- 금지사항/주의사항: 구현보다 먼저 리스크와 엣지 케이스를 드러내야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, node, Playwright, playwright, python, rg
- 원문 description: |

### plan-tune

- 경로: `/Users/su/.claude/skills/gstack/plan-tune/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP
- 원문 description: |

### qa-only

- 경로: `/Users/su/.claude/skills/gstack/qa-only/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, rg
- 원문 description: |

### qa

- 경로: `/Users/su/.claude/skills/gstack/qa/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, node, npm, Playwright, playwright, python
- 원문 description: |

### retro

- 경로: `/Users/su/.claude/skills/gstack/retro/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, MCP, node
- 원문 description: |

### review

- 경로: `/Users/su/.claude/skills/gstack/review/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, node, npm, python, rg, Vercel
- 원문 description: |

### scrape

- 경로: `/Users/su/.claude/skills/gstack/scrape/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, MCP, rg
- 원문 description: |

### setup-browser-cookies

- 경로: `/Users/su/.claude/skills/gstack/setup-browser-cookies/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, git, GitHub, MCP, Playwright
- 원문 description: |

### setup-deploy

- 경로: `/Users/su/.claude/skills/gstack/setup-deploy/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP, Vercel, vercel
- 원문 description: |

### setup-gbrain

- 경로: `/Users/su/.claude/skills/gstack/setup-gbrain/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP, python, rg
- 원문 description: |

### ship

- 경로: `/Users/su/.claude/skills/gstack/ship/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, curl, gh, git, GitHub, MCP, node, npm, Playwright, playwright, python, rg
- 원문 description: |

### skillify

- 경로: `/Users/su/.claude/skills/gstack/skillify/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, gh, git, GitHub, MCP, Playwright, rg
- 원문 description: |

### sync-gbrain

- 경로: `/Users/su/.claude/skills/gstack/sync-gbrain/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, git, GitHub, MCP, rg
- 원문 description: |

### unfreeze

- 경로: `/Users/su/.claude/skills/gstack/unfreeze/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: git
- 원문 description: |

### moai-skill

- 경로: `/Users/su/.claude/skills/moai-skill/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: MoAI-ADK Skill

### moai

- 경로: `/Users/su/.claude/skills/moai/SKILL.md`
- 분류: Claude-side installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: moai

### control-in-app-browser

- 경로: `/Users/su/.codex/plugins/cache/openai-bundled/browser/26.601.21317/skills/control-in-app-browser/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, gh, MCP, node, Playwright, playwright
- 원문 description: Control the in-app Browser. Use to open, navigate, inspect, test, click, type, screenshot, or verify local targets such as localhost, 127.0.0.1, ::1, file://, the current in-app browser tab, and websites shown side by side inside Codex.

### control-chrome

- 경로: `/Users/su/.codex/plugins/cache/openai-bundled/chrome/26.601.21317/skills/control-chrome/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, gh, MCP, node, Playwright, playwright
- 원문 description: Control the user's Chrome browser. Use for browser tasks that require the user's cookies, logged-in sessions, existing tabs, extensions, or remote authenticated sites.

### buyer-investor-list

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/buyer-investor-list/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: build prioritized buyer, investor, lender, or sponsor universes for ib processes. use when the user asks for target lists, outreach waves, rationale, or tracker-ready parties. do not use to run the live process; use deal-process-tracker.

### capital-markets-issuance

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/capital-markets-issuance/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: frame issuer financing and capital-markets execution options. use when the user asks about ecm, dcm, private placements, market window, investor targeting, or use of proceeds. do not use for borrower credit approval.

### cim-builder

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/cim-builder/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Draft or refresh buyer-facing CIMs, teasers, CIM storyboards, lender presentations, and management presentations. Do not use for independent CIM diligence; use cim-teardown.

### cim-teardown

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/cim-teardown/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: analyze seller materials into claims, diligence gaps, red flags, and model handoffs. use when the user asks to tear down a cim or banker deck. do not use to write the cim; use cim-builder.

### company-tearsheet

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/company-tearsheet/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Create source-backed banker-facing company, target, borrower, issuer, or counterparty tearsheets. Use for baseline profiles, coverage screens, deal-screen inputs, and meeting context. Do not use for full memos, models, decks, or diligence reports.

### comps-valuation

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/comps-valuation/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Produce source-backed trading-comps valuation for Investment Banking in report or workbook mode. Use for peer selection, trading multiples, implied valuation, Excel or Sheets comps models, EV bridges, refreshes, pressure tests, and workbook QA. Do not use for DCF, LBO, merger, three-statement, or non-banker investment decisions.

### covenant-package-analyzer

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/covenant-package-analyzer/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Analyze credit documents for covenant definitions, baskets, leakage, headroom mechanics, amendments, and waivers. Use for finance-side covenant reviews, not legal advice.

### dcf-model-builder

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/dcf-model-builder/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Use when building code-backed DCF exports, WACC/terminal value work, EV-to-equity bridges, sensitivities, or price targets; not comps-only.

### deal-process-tracker

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/deal-process-tracker/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, python
- 원문 description: Build, update, or reconstruct IB deal-process trackers in a banker-facing workbook. Use for buyer progression, outreach, NDAs, access, diligence, bids, deadlines, process status, or proxy-disclosed sale-process chronology. Do not use to create buyer universes from scratch or write narrative HTML reports.

### distressed-recovery-waterfall

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/distressed-recovery-waterfall/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Analyze distressed capital structures and recovery waterfalls. Use when the user asks about claims, lien priority, fulcrum security, plan value, liquidation value, sale paths, or restructuring recoveries. Do not use for standard LBO modeling.

### financials-normalizer

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/financials-normalizer/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: convert messy deal financials into model-ready statements, kpi schedules, source maps, and qa flags. use when an ib workflow needs spreading, normalization, or reconciliation. do not use for generic spreadsheet cleanup; use excel-data-cleaner.

### ib-deck-qc

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/ib-deck-qc/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, gh, python
- 원문 description: quality-control investment-banking decks and reports before circulation. use when the user asks to check numbers, units, sources, charts, footnotes, formatting, or page takeaways. do not use to build the deck from scratch.

### investment-banking

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/investment-banking/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: gh, python
- 원문 description: Route Investment Banking work only when the user explicitly names or tags Investment Banking or unmistakably requests banker-owned transaction execution, such as a sell-side process, CIM, M&A/merger model, ECM/DCM/LevFin client mandate, or restructuring pitch. Do not use for generic memos, reports, decks, models, valuations, spreadsheets, research, or meeting preparation.

### lbo-model-build

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/lbo-model-build/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Build sponsor LBO models for sources and uses, debt, sweep, liquidity, returns, and downside underwriting. Use for take-privates, acquisition financing, or leverage screens; not DCF-only work.

### meeting-prep

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/meeting-prep/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: prepare ib meeting briefs, question lists, and debrief follow-ups. use when the user asks for call prep, buyer or lender meeting materials, diligence questions, or action tracking. do not use for full memo drafting.

### memo-builder

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/memo-builder/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: draft or review investment-banking memos from existing analysis. use when the user wants a client, committee, board, financing, process, or diligence note. do not use to build source models, decks, trackers, or tearsheets.

### merger-model-builder

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/merger-model-builder/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Build merger and accretion/dilution models for consideration, pro forma ownership, synergies, purchase accounting, financing mix, or EPS impact. Use for strategic M&A modeling; not standalone DCF or LBO work.

### model-audit-tieout

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/model-audit-tieout/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, python
- 원문 description: audit existing financial models and workbook outputs. use when the user asks to check formulas, sources, assumptions, sensitivities, links, or model readiness. do not use to build a new model from scratch.

### pitch-deck-builder

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/pitch-deck-builder/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: build investment-banking pitch deck outlines, page plans, and draft slide content. use when the user asks to create or refresh a banking pitch or client discussion deck. do not mark final client-ready; route final circulation qc to ib-deck-qc.

### private-credit-underwriting

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/private-credit-underwriting/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Build borrower-level private credit underwriting views for lender cases, credit memos, debt sizing, downside, liquidity, collateral, recovery, and proceed/decline decisions. Use for lender-side credit decisions, not issuer financing strategy.

### scenario-sensitivity-generator

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/scenario-sensitivity-generator/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: create scenario, sensitivity, stress-test, and breakeven frameworks for ib analyses. use when the user asks to pressure-test model drivers, cases, downside paths, or decision thresholds. do not build base models.

### three-statement-model-builder

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/three-statement-model-builder/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, python
- 원문 description: Use when building integrated three-statement operating model exports with linked IS, BS, CF, drivers, checks, scenarios, or formula templates.

### user-context

- 경로: `/Users/su/.codex/plugins/cache/openai-curated-remote/investment-banking/0.1.24/skills/user-context/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: python
- 원문 description: Start onboarding, initialize, inspect, save, update, forget, export, or explicitly reset the Investment Banking plugin's local user context, source setup, or optional automation setup. Use when the user explicitly asks to get started, orient, or manage Investment Banking saved preferences, source pointers, context storage, or recurring automation.

### gh-address-comments

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/github/5e86d584/skills/gh-address-comments/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: gh, git, GitHub
- 원문 description: Address actionable GitHub pull request review feedback. Use when the user wants to inspect unresolved review threads, requested changes, or inline review comments on a PR, then implement selected fixes. Use the GitHub app for PR metadata and flat comment reads, and use the bundled GraphQL script via `gh` whenever thread-level state, resolution status, or inline review context matters.

### gh-fix-ci

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/github/5e86d584/skills/gh-fix-ci/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, GitHub, python
- 원문 description: Use when a user asks to debug or fix failing GitHub PR checks that run in GitHub Actions. Use the GitHub app from this plugin for PR metadata and patch context, and use `gh` for Actions check and log inspection before implementing any approved fix.

### github

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/github/5e86d584/skills/github/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: gh, git, GitHub
- 원문 description: Triage and orient GitHub repository, pull request, and issue work through the connected GitHub app. Use when the user asks for general GitHub help, wants PR or issue summaries, or needs repository context before choosing a more specific GitHub workflow.

### yeet

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/github/5e86d584/skills/yeet/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: gh, git, GitHub
- 원문 description: Publish local changes to GitHub by confirming scope, committing intentionally, pushing the branch, and opening a draft PR through the GitHub app from this plugin, with `gh` used only as a fallback where connector coverage is insufficient.

### agent-browser-verify

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/agent-browser-verify/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, npm, npx, Vercel, vercel
- 원문 description: Automated browser verification for dev servers. Triggers when a dev server starts to run a visual gut-check with agent-browser — verifies the page loads, checks for console errors, validates key UI elements, and reports pass/fail before continuing.

### agent-browser

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/agent-browser/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, npm, Playwright, playwright, Vercel, vercel
- 원문 description: Browser automation CLI for AI agents. Use when the user needs to interact with websites, verify dev server output, test web apps, navigate pages, fill forms, click buttons, take screenshots, extract data, or automate any browser task. Also triggers when a dev server starts so you can verify it visually.

### ai-elements

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/ai-elements/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: Chrome, git, GitHub, npm, npx, Vercel, vercel
- 원문 description: AI Elements component library guidance — pre-built React components for AI interfaces built on shadcn/ui. Use when building chat UIs, message displays, tool call rendering, streaming responses, reasoning panels, or any AI-native interface with the AI SDK.

### ai-gateway

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/ai-gateway/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: curl, gh, GitHub, npm, Vercel, vercel
- 원문 description: Vercel AI Gateway expert guidance. Use when configuring model routing, provider failover, cost tracking, or managing multiple AI providers through a unified API.

### ai-generation-persistence

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/ai-generation-persistence/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, vercel, Vercel
- 원문 description: AI generation persistence patterns — unique IDs, addressable URLs, database storage, and cost tracking for every LLM generation

### ai-sdk

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/ai-sdk/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, GitHub, MCP, node, npm, npx, Vercel, vercel
- 원문 description: Vercel AI SDK expert guidance. Use when building AI-powered features — chat interfaces, text generation, structured output, tool calling, agents, MCP integration, streaming, embeddings, reranking, image generation, or working with any LLM provider.

### auth

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/auth/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, npm, npx, Vercel, vercel
- 원문 description: Authentication integration guidance — Clerk (native Vercel Marketplace), Descope, and Auth0 setup for Next.js applications. Covers middleware auth patterns, sign-in/sign-up flows, and Marketplace provisioning. Use when implementing user authentication.

### bootstrap

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/bootstrap/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: gh, node, npm, npx, Vercel, vercel
- 원문 description: Project bootstrapping orchestrator for repos that depend on Vercel-linked resources (databases, auth, and managed integrations). Use when setting up or repairing a repository so linking, environment provisioning, env pulls, and first-run db/dev commands happen in the correct safe order.

### chat-sdk

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/chat-sdk/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, GitHub, npm, rg, Vercel, vercel
- 원문 description: Vercel Chat SDK expert guidance. Use when building multi-platform chat bots — Slack, Telegram, Microsoft Teams, Discord, Google Chat, GitHub, Linear — with a single codebase. Covers the Chat class, adapters, threads, messages, cards, modals, streaming, state management, and webhook setup.

### cms

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/cms/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, GitHub, npm, npx, Vercel, vercel
- 원문 description: Headless CMS integration guidance — Sanity (native Vercel Marketplace), Contentful, DatoCMS, Storyblok, and Builder.io. Covers studio setup, content modeling, preview mode, revalidation webhooks, and Visual Editing. Use when building content-driven sites with a headless CMS on Vercel.

### cron-jobs

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/cron-jobs/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: vercel, Vercel
- 원문 description: Vercel Cron Jobs configuration and best practices. Use when adding, editing, or debugging scheduled tasks in vercel.json.

### deployments-cicd

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/deployments-cicd/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, node, npm, npx, Playwright, playwright, Vercel, vercel
- 원문 description: Vercel deployment and CI/CD expert guidance. Use when deploying, promoting, rolling back, inspecting deployments, building with --prebuilt, or configuring CI workflow files for Vercel.

### email

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/email/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, npm, npx, Vercel, vercel
- 원문 description: Email sending integration guidance — Resend (native Vercel Marketplace) with React Email templates. Covers API setup, transactional emails, domain verification, and template patterns. Use when sending emails from a Vercel-deployed application.

### env-vars

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/env-vars/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, node, npm, npx, Vercel, vercel
- 원문 description: Vercel environment variable expert guidance. Use when working with .env files, vercel env commands, OIDC tokens, or managing environment-specific configuration.

### geist

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/geist/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, npm, vercel, Vercel
- 원문 description: Expert guidance for Geist, Vercel's default typography system and font family for precise Next.js interfaces. Use when configuring Geist Sans, Geist Mono, or Geist Pixel, setting up font imports, or applying Vercel typography and aesthetic guidance.

### geistdocs

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/geistdocs/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, npm, npx, Vercel, vercel
- 원문 description: Expert guidance for Geistdocs, Vercel's documentation template built with Next.js and Fumadocs — MDX authoring, configuration, AI chat, i18n, feedback, deployment. Use when creating documentation sites, configuring geistdocs, writing MDX content, or setting up docs infrastructure.

### investigation-mode

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/investigation-mode/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, Vercel, vercel
- 원문 description: Orchestrated debugging coordinator. Triggers on frustration signals (stuck, hung, broken, waiting) and systematically triages: runtime logs → workflow status → browser verify → deploy/env. Reports findings at every step.

### json-render

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/json-render/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: AI chat response rendering guidance — handling UIMessage parts, tool call displays, streaming states, and structured data presentation. Use when building custom chat UIs, rendering tool results, or troubleshooting AI response display issues.

### marketplace

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/marketplace/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, npx, Vercel, vercel
- 원문 description: Vercel Marketplace expert guidance — discovering, installing, and building integrations, auto-provisioned environment variables, unified billing, and the vercel integration CLI. Use when consuming third-party services, building custom integrations, or managing marketplace resources on Vercel.

### micro

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/micro/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, npm, npx, Vercel, vercel
- 원문 description: Expert guidance for micro — asynchronous HTTP microservices framework by Vercel. Use when building lightweight HTTP servers, API endpoints, or microservices using the micro library.

### ncc

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/ncc/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, node, npm, Vercel, vercel
- 원문 description: 'Expert guidance for @vercel/ncc — a simple CLI for compiling Node.js modules into a single file with all dependencies included. Use when bundling serverless functions, CLI tools, or any Node.js project into a self-contained file.'

### next-forge

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/next-forge/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, npm, npx, Vercel, vercel
- 원문 description: 'next-forge expert guidance — production-grade Turborepo monorepo SaaS starter by Vercel. Use when working in a next-forge project, scaffolding with `npx next-forge init`, or editing @repo/* workspace packages.'

### nextjs

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/nextjs/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, GitHub, MCP, node, npm, npx, Vercel, vercel
- 원문 description: Next.js App Router expert guidance. Use when building, debugging, or architecting Next.js applications — routing, Server Components, Server Actions, Cache Components, layouts, middleware/proxy, data fetching, rendering strategies, and deployment on Vercel.

### observability

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/observability/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, MCP, node, npm, npx, Vercel, vercel
- 원문 description: Vercel Observability expert guidance — Drains (logs, traces, speed insights, web analytics), Web Analytics, Speed Insights, runtime logs, custom events, OpenTelemetry integration, and monitoring dashboards. Use when instrumenting, debugging, or optimizing application performance and user experience on Vercel.

### payments

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/payments/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, npm, Vercel, vercel
- 원문 description: Stripe payments integration guidance — native Vercel Marketplace setup, checkout sessions, webhook handling, subscription billing, and the Stripe SDK. Use when implementing payments, subscriptions, or processing transactions.

### react-best-practices

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/react-best-practices/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 계획과 제품 판단을 더 엄격하게 검토하는 스킬입니다.
- 주요 사용 시점: 방향성, 제품 품질, 개발자 경험, 아키텍처 의사결정 전에 사용합니다.
- 금지사항/주의사항: 검토가 실행을 지연시키는 의식이 되지 않게 결론과 기준을 남겨야 합니다.
- 명령어/도구 의존성: gh, Vercel
- 원문 description: React best-practices reviewer for TSX files. Triggers after editing multiple TSX components to run a condensed quality checklist covering component structure, hooks usage, accessibility, performance, and TypeScript patterns.

### routing-middleware

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/routing-middleware/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: node, npx, vercel, Vercel
- 원문 description: Vercel Routing Middleware guidance — request interception before cache, rewrites, redirects, personalization. Works with any framework. Supports Edge, Node.js, and Bun runtimes. Use when intercepting requests at the platform level.

### runtime-cache

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/runtime-cache/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: npm, vercel, Vercel
- 원문 description: Vercel Runtime Cache API guidance — ephemeral per-region key-value cache with tag-based invalidation. Shared across Functions, Routing Middleware, and Builds. Use when implementing caching strategies beyond framework-level caching.

### satori

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/satori/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, npm, vercel, Vercel
- 원문 description: Expert guidance for Satori — Vercel's library that converts HTML and CSS to SVG, commonly used to generate dynamic OG images for Next.js and other frameworks.

### shadcn

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/shadcn/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, gh, GitHub, MCP, npm, npx, Vercel
- 원문 description: shadcn/ui expert guidance — CLI, component installation, composition patterns, custom registries, theming, Tailwind CSS integration, and high-quality interface design. Use when initializing shadcn, adding components, composing product UI, building custom registries, configuring themes, or troubleshooting component issues.

### sign-in-with-vercel

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/sign-in-with-vercel/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: vercel, Vercel
- 원문 description: Sign in with Vercel guidance — OAuth 2.0/OIDC identity provider for user authentication via Vercel accounts. Use when implementing user login with Vercel as the identity provider.

### swr

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/swr/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: npm, rg, vercel, Vercel
- 원문 description: SWR data-fetching expert guidance. Use when building React apps with client-side data fetching, caching, revalidation, mutations, optimistic UI, pagination, or infinite loading using the SWR library.

### turbopack

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/turbopack/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browser, Chrome, GitHub, npm, Vercel, vercel
- 원문 description: Turbopack expert guidance. Use when configuring the Next.js bundler, optimizing HMR, debugging build issues, or understanding the Turbopack vs Webpack differences.

### turborepo

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/turborepo/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, GitHub, node, npm, npx, Vercel, vercel
- 원문 description: Turborepo expert guidance. Use when setting up or optimizing monorepo builds, configuring task caching, remote caching, parallel execution, or the --affected flag for incremental CI.

### v0-dev

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/v0-dev/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, git, GitHub, MCP, npm, npx, rg, Vercel, vercel
- 원문 description: v0 by Vercel expert guidance. Use when discussing AI code generation, generating UI components from prompts, v0 CLI usage, v0 SDK/API integration, or integrating v0 into development workflows with GitHub and Vercel deployment.

### vercel-agent

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-agent/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, npm, vercel, Vercel
- 원문 description: Vercel Agent guidance — AI-powered code review, incident investigation, and SDK installation. Automates PR analysis and anomaly debugging. Use when configuring or understanding Vercel's AI development tools.

### vercel-api

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-api/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, GitHub, MCP, npm, Vercel, vercel
- 원문 description: Vercel app and REST API expert guidance. Use when the agent needs live access to Vercel projects, deployments, environment variables, domains, logs, or documentation through the connected Vercel app or REST API.

### vercel-cli

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-cli/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: git, GitHub, MCP, npm, npx, Vercel, vercel
- 원문 description: Vercel CLI expert guidance. Use when deploying, managing environment variables, linking projects, viewing logs, managing domains, or interacting with the Vercel platform from the command line.

### vercel-firewall

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-firewall/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, curl, gh, Vercel, vercel
- 원문 description: Vercel Firewall and security expert guidance. Use when configuring DDoS protection, WAF rules, rate limiting, bot filtering, IP allow/block lists, OWASP rulesets, Attack Challenge Mode, or any security configuration on the Vercel platform.

### vercel-flags

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-flags/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, GitHub, npm, Vercel, vercel
- 원문 description: Vercel Flags guidance — feature flags platform with unified dashboard, Flags Explorer, gradual rollouts, A/B testing, and provider adapters. Use when implementing feature flags, experimentation, or staged rollouts.

### vercel-functions

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-functions/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: GitHub, node, npm, Vercel, vercel
- 원문 description: Vercel Functions expert guidance — Serverless Functions, Edge Functions, Fluid Compute, streaming, Cron Jobs, and runtime configuration. Use when configuring, debugging, or optimizing server-side code running on Vercel.

### vercel-queues

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-queues/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: npm, vercel, Vercel
- 원문 description: Vercel Queues guidance (public beta) — durable event streaming with topics, consumer groups, retries, and delayed delivery. $0.60/1M ops. Powers Workflow DevKit. Use when building async processing, fan-out patterns, or event-driven architectures.

### vercel-sandbox

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-sandbox/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: git, GitHub, node, npm, python, Vercel, vercel
- 원문 description: Vercel Sandbox guidance — ephemeral Firecracker microVMs for running untrusted code safely. Supports AI agents, code generation, and experimentation. Use when executing user-generated or AI-generated code in isolation.

### vercel-services

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-services/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browser, python, vercel, Vercel
- 원문 description: Vercel Services — deploy multiple services within a single Vercel project. Use for monorepo layouts or when combining a backend (Python, Go) with a frontend (Next.js, Vite) in one deployment.

### vercel-storage

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/vercel-storage/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, GitHub, npm, npx, Vercel, vercel
- 원문 description: Vercel storage expert guidance — Blob, Edge Config, and Marketplace storage (Neon Postgres, Upstash Redis). Use when choosing, configuring, or using data storage with Vercel applications.

### verification

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/verification/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 브라우저 자동화와 화면 검증을 돕는 스킬입니다.
- 주요 사용 시점: 웹 페이지 탐색, 클릭, 폼 입력, 스크린샷, 로컬/원격 UI QA 때 사용합니다.
- 금지사항/주의사항: 인증 정보, 쿠키, 실제 사용자 세션을 다룰 때 범위와 보안을 확인해야 합니다.
- 명령어/도구 의존성: browse, browser, git, npm, Playwright, playwright, Vercel, vercel
- 원문 description: Full-story verification — infers what the user is building, then verifies the complete flow end-to-end: browser → API → data → response. Triggers on dev server start and 'why isn't this working' signals.

### workflow

- 경로: `/Users/su/.codex/plugins/cache/openai-curated/vercel/5e86d584/skills/workflow/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, GitHub, npm, npx, Vercel, vercel
- 원문 description: Vercel Workflow DevKit (WDK) expert guidance. Use when building durable workflows, long-running tasks, API routes or agents that need pause/resume, retries, step-based execution, or crash-safe orchestration with Vercel Workflow.

### documents

- 경로: `/Users/su/.codex/plugins/cache/openai-primary-runtime/documents/26.601.10930/skills/documents/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browser, gh, MCP, node, npm, python
- 원문 description: Create, edit, redline, and comment on `.docx`, Word, and Google Docs-targeted document artifacts inside the container, with a strict render-and-verify workflow. Use `render_docx.py` to generate page PNGs (and optional PDF) for visual QA, then iterate until layout is flawless before delivering the final document.

### Presentations

- 경로: `/Users/su/.codex/plugins/cache/openai-primary-runtime/presentations/26.601.10930/skills/presentations/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: Chrome, gh, node
- 원문 description: Build PowerPoint PPTX decks with artifact-tool presentation JSX

### Spreadsheets

- 경로: `/Users/su/.codex/plugins/cache/openai-primary-runtime/spreadsheets/26.601.10930/skills/spreadsheets/SKILL.md`
- 분류: Codex plugin skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, MCP, node, npm, python
- 원문 description: Use this skill when a user requests to create, modify, analyze, visualize, or work with spreadsheet files (`.xlsx`, `.xls`, `.csv`, `.tsv`) or Google Sheets-targeted spreadsheet artifacts with formulas, formatting, charts, tables, and recalculation.

### imagegen

- 경로: `/Users/su/.codex/skills/.system/imagegen/SKILL.md`
- 분류: Codex system skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, python
- 원문 description: Generate or edit raster images when the task benefits from AI-created bitmap visuals such as photos, illustrations, textures, sprites, mockups, or transparent-background cutouts. Use when Codex should create a brand-new image, transform an existing image, or derive visual variants from references, and the output should be a bitmap asset rather than repo-native code or vector. Do not use when the task is better handled by editing existing SVG/vector/code-native assets, extending an established icon or logo system, or building the visual directly in HTML/CSS/canvas.

### openai-docs

- 경로: `/Users/su/.codex/skills/.system/openai-docs/SKILL.md`
- 분류: Codex system skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, Chrome, curl, gh, GitHub, MCP, node
- 원문 description: Use when the user asks how to build with OpenAI products or APIs, asks about Codex itself or choosing Codex surfaces, needs up-to-date official documentation with citations, help choosing the latest model for a use case, or model upgrade and prompt-upgrade guidance; use OpenAI docs MCP tools for non-Codex docs questions, use the Codex manual helper first for broad Codex self-knowledge, and restrict fallback browsing to official OpenAI domains.

### plugin-creator

- 경로: `/Users/su/.codex/skills/.system/plugin-creator/SKILL.md`
- 분류: Codex system skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, MCP, python
- 원문 description: Create and scaffold plugin directories for Codex with a required `.codex-plugin/plugin.json`, optional plugin folders/files, valid manifest defaults, and personal-marketplace entries by default. Use when Codex needs to create a new personal plugin, add optional plugin structure, generate or update marketplace entries for plugin ordering and availability metadata, or update an existing local plugin during development with the CLI-driven cachebuster and reinstall flow.

### skill-creator

- 경로: `/Users/su/.codex/skills/.system/skill-creator/SKILL.md`
- 분류: Codex system skill
- 한국어 설명: 새 Codex skill을 설계하고 만드는 스킬입니다.
- 주요 사용 시점: 새 skill 생성 또는 기존 skill 업데이트 요청에 사용합니다.
- 금지사항/주의사항: frontmatter와 routing description을 훼손하지 않아야 합니다.
- 명령어/도구 의존성: gh
- 원문 description: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Codex's capabilities with specialized knowledge, workflows, or tool integrations.

### skill-installer

- 경로: `/Users/su/.codex/skills/.system/skill-installer/SKILL.md`
- 분류: Codex system skill
- 한국어 설명: 스킬, 플러그인, MCP, 에이전트 구성을 다루는 스킬입니다.
- 주요 사용 시점: 도구 통합, skill/package 작성, MCP 서버 설계 때 사용합니다.
- 금지사항/주의사항: 라우팅 설명과 manifest를 망가뜨리면 자동 선택 안정성이 떨어집니다.
- 명령어/도구 의존성: git, GitHub
- 원문 description: Install Codex skills into $CODEX_HOME/skills from a curated list or a GitHub repo path. Use when a user asks to list installable skills, install a curated skill, or install a skill from another repo (including private repos).

### brainstorming

- 경로: `/Users/su/.codex/skills/brainstorming/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, gh, MCP
- 원문 description: You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.

### dispatching-parallel-agents

- 경로: `/Users/su/.codex/skills/dispatching-parallel-agents/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies

### executing-plans

- 경로: `/Users/su/.codex/skills/executing-plans/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 작성된 구현 계획을 순서대로 실행하고 검증하는 워크플로 스킬입니다.
- 주요 사용 시점: 사용자가 작업지시서나 실행 계획을 준 경우 사용합니다.
- 금지사항/주의사항: 계획이 막히면 억지 진행하지 말고 이유를 드러내야 합니다.
- 명령어/도구 의존성: gh
- 원문 description: Use when you have a written implementation plan to execute in a separate session with review checkpoints

### finishing-a-development-branch

- 경로: `/Users/su/.codex/skills/finishing-a-development-branch/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: gh, git, npm
- 원문 description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup

### karpathy-guidelines

- 경로: `/Users/su/.codex/skills/karpathy-guidelines/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 코딩 실수를 줄이기 위한 기본 운영 원칙입니다. 단순성, 작은 변경, 모호성 노출, 검증 전 완료 주장 금지를 강제합니다.
- 주요 사용 시점: 코드 작성, 리뷰, 리팩토링 전후에 사용합니다.
- 금지사항/주의사항: 과한 추상화나 검증 없는 성공 주장을 피해야 합니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: Behavioral guidelines to reduce common LLM coding mistakes. Use when writing, reviewing, or refactoring code to avoid overcomplication, make surgical changes, surface assumptions, and define verifiable success criteria.

### receiving-code-review

- 경로: `/Users/su/.codex/skills/receiving-code-review/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: gh, GitHub
- 원문 description: Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation

### requesting-code-review

- 경로: `/Users/su/.codex/skills/requesting-code-review/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 검증과 품질 확인을 체계화하는 스킬입니다.
- 주요 사용 시점: 테스트, QA, 회귀 확인, 릴리즈 전 검증에 사용합니다.
- 금지사항/주의사항: 검증 결과를 실제 증거 없이 성공으로 포장하지 않아야 합니다.
- 명령어/도구 의존성: git
- 원문 description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements

### subagent-driven-development

- 경로: `/Users/su/.codex/skills/subagent-driven-development/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: gh, git
- 원문 description: Use when executing implementation plans with independent tasks in the current session

### systematic-debugging

- 경로: `/Users/su/.codex/skills/systematic-debugging/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 버그를 조사, 분석, 가설, 구현 순서로 다루는 디버깅 스킬입니다.
- 주요 사용 시점: 원인을 모르는 오류나 회귀가 있을 때 사용합니다.
- 금지사항/주의사항: 루트 원인 없이 임시 패치로 덮지 않습니다.
- 명령어/도구 의존성: gh
- 원문 description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes

### test-driven-development

- 경로: `/Users/su/.codex/skills/test-driven-development/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 실패하는 테스트를 먼저 만들고 구현으로 통과시키는 개발 스킬입니다.
- 주요 사용 시점: 버그 수정이나 기능 추가에서 검증 가능한 조건이 있을 때 사용합니다.
- 금지사항/주의사항: 테스트가 의미 없이 구현을 따라가게 만들면 안 됩니다.
- 명령어/도구 의존성: gh, npm
- 원문 description: Use when implementing any feature or bugfix, before writing implementation code

### understand-chat

- 경로: `/Users/su/.codex/skills/understand-chat/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 코드베이스 구조와 지식을 분석하는 스킬입니다.
- 주요 사용 시점: 영향 범위가 불명확하거나 큰 구조를 이해해야 할 때 사용합니다.
- 금지사항/주의사항: 생성된 분석 산출물을 무조건 커밋하지 않아야 합니다.
- 명령어/도구 의존성: gh, node
- 원문 description: Use when you need to ask questions about a codebase or understand code using a knowledge graph

### understand-dashboard

- 경로: `/Users/su/.codex/skills/understand-dashboard/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 코드베이스 구조와 지식을 분석하는 스킬입니다.
- 주요 사용 시점: 영향 범위가 불명확하거나 큰 구조를 이해해야 할 때 사용합니다.
- 금지사항/주의사항: 생성된 분석 산출물을 무조건 커밋하지 않아야 합니다.
- 명령어/도구 의존성: browse, browser, npm, npx
- 원문 description: Launch the interactive web dashboard to visualize a codebase's knowledge graph

### understand-diff

- 경로: `/Users/su/.codex/skills/understand-diff/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 코드베이스 구조와 지식을 분석하는 스킬입니다.
- 주요 사용 시점: 영향 범위가 불명확하거나 큰 구조를 이해해야 할 때 사용합니다.
- 금지사항/주의사항: 생성된 분석 산출물을 무조건 커밋하지 않아야 합니다.
- 명령어/도구 의존성: git, node
- 원문 description: Use when you need to analyze git diffs or pull requests to understand what changed, affected components, and risks

### understand-domain

- 경로: `/Users/su/.codex/skills/understand-domain/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 코드베이스 구조와 지식을 분석하는 스킬입니다.
- 주요 사용 시점: 영향 범위가 불명확하거나 큰 구조를 이해해야 할 때 사용합니다.
- 금지사항/주의사항: 생성된 분석 산출물을 무조건 커밋하지 않아야 합니다.
- 명령어/도구 의존성: git, node, npm, python
- 원문 description: Extract business domain knowledge from a codebase and generate an interactive domain flow graph. Works standalone (lightweight scan) or derives from an existing /understand knowledge graph.

### understand-explain

- 경로: `/Users/su/.codex/skills/understand-explain/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: node
- 원문 description: Use when you need a deep-dive explanation of a specific file, function, or module in the codebase

### understand-knowledge

- 경로: `/Users/su/.codex/skills/understand-knowledge/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: git, GitHub, node, python
- 원문 description: Analyze a Karpathy-pattern LLM wiki knowledge base and generate an interactive knowledge graph with entity extraction, implicit relationships, and topic clustering.

### understand-onboard

- 경로: `/Users/su/.codex/skills/understand-onboard/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: gh, node
- 원문 description: Use when you need to generate an onboarding guide for new team members joining a project

### understand

- 경로: `/Users/su/.codex/skills/understand/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: gh, git, node, npm, python
- 원문 description: Analyze a codebase to produce an interactive knowledge graph for understanding architecture, components, and relationships

### using-git-worktrees

- 경로: `/Users/su/.codex/skills/using-git-worktrees/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 배포와 릴리즈 흐름을 관리하는 스킬입니다.
- 주요 사용 시점: PR 생성, 배포, CI 수정, 운영 검증 때 사용합니다.
- 금지사항/주의사항: 실패한 CI나 배포를 통과처럼 보고하지 않아야 합니다.
- 명령어/도구 의존성: git, npm
- 원문 description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or git worktree fallback

### using-superpowers

- 경로: `/Users/su/.codex/skills/using-superpowers/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 제품 UI와 시각 품질을 개선하는 스킬입니다.
- 주요 사용 시점: 화면 설계, 디자인 리뷰, 프론트엔드 구현, 시각 QA 때 사용합니다.
- 금지사항/주의사항: 겉모습만 만들고 실제 동작이나 접근성을 놓치지 않아야 합니다.
- 명령어/도구 의존성: MCP
- 원문 description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions

### verification-before-completion

- 경로: `/Users/su/.codex/skills/verification-before-completion/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 완료·수정·통과를 주장하기 전에 실제 검증 증거를 요구하는 스킬입니다.
- 주요 사용 시점: 커밋, 푸시, PR, 완료 보고 직전에 사용합니다.
- 금지사항/주의사항: 증거 없이 “완료”라고 말하지 않습니다.
- 명령어/도구 의존성: 명시적 도구 의존성 발견 없음
- 원문 description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always

### writing-plans

- 경로: `/Users/su/.codex/skills/writing-plans/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 복잡한 작업을 실행 가능한 계획으로 정리하는 스킬입니다.
- 주요 사용 시점: 다단계 기능, 구조 변경, 제품 방향 결정 전에 사용합니다.
- 금지사항/주의사항: 계획만 쓰고 검증 기준을 빼먹지 않아야 합니다.
- 명령어/도구 의존성: git, python
- 원문 description: Use when you have a spec or requirements for a multi-step task, before touching code

### writing-skills

- 경로: `/Users/su/.codex/skills/writing-skills/SKILL.md`
- 분류: Codex installed skill
- 한국어 설명: 스킬 작성, 수정, 배포 검증을 위한 지침 스킬입니다.
- 주요 사용 시점: SKILL.md를 만들거나 고칠 때 사용합니다.
- 금지사항/주의사항: 자동 생성 파일과 라우팅 키워드를 함부로 바꾸지 않습니다.
- 명령어/도구 의존성: gh, git
- 원문 description: Use when creating new skills, editing existing skills, or verifying skills work before deployment
