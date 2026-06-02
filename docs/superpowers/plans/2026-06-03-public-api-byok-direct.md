# Public API BYOK Direct Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users connect Korean public APIs with their own keys first, while keeping future MyTeam proxy support honest and optional.

**Architecture:** Add a credential schema layer above `SecureCredentialStore` so providers can declare one or more fields. Naver News uses BYOK direct with `clientID` and `clientSecret`; DART uses `apiKey`; KMA uses `serviceKey`. Proxy mode is represented as metadata and backlog, but never shown as available until a real proxy exists.

**Tech Stack:** Swift, SwiftUI, macOS Keychain, `URLSession`, existing MyTeam connector health surfaces, `xcodebuild`, `scripts/validate_release_checklist.py`.

---

## What Already Exists

- `MyTeam/ProviderCredential.swift`: owns `ExternalProvider`, display names, descriptions, issue URLs, and current single `keychainKey`.
- `MyTeam/SecureCredentialStore.swift`: central Keychain wrapper. Good, but currently stores one string per provider.
- `MyTeam/CredentialHealth.swift`: separates `.untested`, `.testUnavailable`, `.connected`, and failed states. Keep this.
- `MyTeam/ConnectorSetupCardView.swift`: renders key input/save/delete/test UI. Needs schema-driven multi-field UI.
- `MyTeam/ConnectionCenterView.swift`: separates AI providers and data providers. Needs direct/proxy availability copy.
- `MyTeam/KSkillAssistRuntime.swift`: currently tells users Naver/DART are assist-only unless they provide links/text. This stays true until direct connectors are actually used by runtime.
- `MyTeam/StockEvidenceCollector.swift`: already has web/browser evidence fallback. Naver News direct API should be an additional source, not a replacement.

## Direction Decision

Use **BYOK direct first**.

`k-skill` Naver News is not really "API 없이" at the system level. It uses `k-skill-proxy`, and the proxy injects `NAVER_SEARCH_CLIENT_ID` and `NAVER_SEARCH_CLIENT_SECRET`. That is a good future shape for MyTeam's optional proxy, but we do not have that proxy today. So MyTeam must not say "기본 조회 가능" yet.

```
Today
=====
User key in app
   |
   v
Keychain
   |
   v
Direct provider API
   |
   v
Validated result or clear failure

Later
=====
No user key
   |
   v
MyTeam proxy, if real and deployed
   |
   v
Provider API with server-held key
```

## NOT In Scope

- Proxy server implementation: defer until MyTeam has a real server, quota policy, rate limiting, logging policy, and App Store disclosure copy.
- "기본 조회 가능" UI: forbidden until proxy health check and actual endpoint exist.
- Browser scraping/CAPTCHA bypass: not needed for Naver News Open API and risky for App Store trust.
- Replacing all web evidence fallback: keep fallback, but label sources honestly.
- Editing global installed skill files in `~/.codex/skills` or `~/.agents/skills`: risky because many are auto-generated and current-session tool metadata will not update reliably. Prefer a Korean skill catalog or explicit opt-in patch script.

## State Model

```
No credential
  -> 개인 키 연결 가능

Credential saved
  -> 키 저장됨
  -> not connected

Validator unavailable
  -> 저장됨, 자동 확인 미지원
  -> not connected

Validator success
  -> 사용 가능
  -> connected

Proxy slot with no deployed proxy
  -> 기본 조회 준비 중
  -> not connected
```

## Task 1: Credential Schema Model

**Files:**
- Modify: `MyTeam/ProviderCredential.swift`
- Modify: `MyTeam/SecureCredentialStore.swift`
- Test: `MyTeamTests/CredentialSchemaTests.swift`

- [ ] **Step 1: Write the failing schema test**

```swift
import XCTest
@testable import MyTeam

final class CredentialSchemaTests: XCTestCase {
    func testNaverNewsRequiresClientIDAndClientSecret() {
        let schema = ExternalProvider.naverNews.credentialSchema
        XCTAssertEqual(schema.fields.map(\.id), ["clientID", "clientSecret"])
        XCTAssertEqual(schema.fields[0].label, "Client ID")
        XCTAssertEqual(schema.fields[1].label, "Client Secret")
        XCTAssertTrue(schema.fields[1].isSecret)
    }

    func testDARTAndKMAUseSingleNamedFields() {
        XCTAssertEqual(ExternalProvider.dartDisclosure.credentialSchema.fields.map(\.id), ["apiKey"])
        XCTAssertEqual(ExternalProvider.dartDisclosure.credentialSchema.fields[0].label, "API Key")
        XCTAssertEqual(ExternalProvider.kmaWeather.credentialSchema.fields.map(\.id), ["serviceKey"])
        XCTAssertEqual(ExternalProvider.kmaWeather.credentialSchema.fields[0].label, "Service Key")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project MyTeam/MyTeam.xcodeproj -scheme MyTeamTests -configuration Debug -destination 'platform=macOS' -only-testing:MyTeamTests/CredentialSchemaTests
```

Expected: FAIL because `credentialSchema` does not exist.

- [ ] **Step 3: Add minimal schema types**

Add to `MyTeam/ProviderCredential.swift`:

```swift
struct ProviderCredentialSchema: Equatable, Sendable {
    let fields: [CredentialField]

    var primaryField: CredentialField? {
        fields.first
    }
}

struct CredentialField: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let placeholder: String
    let keychainSuffix: String
    let isSecret: Bool
}

extension ExternalProvider {
    var credentialSchema: ProviderCredentialSchema {
        switch self {
        case .naverNews:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "clientID",
                    label: "Client ID",
                    placeholder: "네이버 개발자 센터 Client ID",
                    keychainSuffix: "clientID",
                    isSecret: false
                ),
                CredentialField(
                    id: "clientSecret",
                    label: "Client Secret",
                    placeholder: "네이버 개발자 센터 Client Secret",
                    keychainSuffix: "clientSecret",
                    isSecret: true
                )
            ])
        case .dartDisclosure:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "apiKey",
                    label: "API Key",
                    placeholder: "OpenDART API Key",
                    keychainSuffix: "apiKey",
                    isSecret: true
                )
            ])
        case .kmaWeather:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "serviceKey",
                    label: "Service Key",
                    placeholder: "공공데이터포털 Service Key",
                    keychainSuffix: "serviceKey",
                    isSecret: true
                )
            ])
        case .openAI, .gemini, .anthropic, .openRouter:
            return ProviderCredentialSchema(fields: [
                CredentialField(
                    id: "apiKey",
                    label: "API Key",
                    placeholder: "API Key",
                    keychainSuffix: "apiKey",
                    isSecret: true
                )
            ])
        }
    }
}
```

- [ ] **Step 4: Add field-specific Keychain helpers**

Add to `MyTeam/SecureCredentialStore.swift`:

```swift
func save(provider: ExternalProvider, field: CredentialField, value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    return KeychainManager.save(key: keychainKey(provider: provider, field: field), value: trimmed)
}

func read(provider: ExternalProvider, field: CredentialField) -> String? {
    KeychainManager.load(key: keychainKey(provider: provider, field: field))
}

func delete(provider: ExternalProvider, field: CredentialField) -> Bool {
    KeychainManager.delete(key: keychainKey(provider: provider, field: field))
}

func hasAllRequiredFields(for provider: ExternalProvider) -> Bool {
    provider.credentialSchema.fields.allSatisfy { field in
        guard let value = read(provider: provider, field: field) else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private func keychainKey(provider: ExternalProvider, field: CredentialField) -> String {
    "\(provider.rawValue).\(field.keychainSuffix)"
}
```

Keep existing `save(provider:key:)`, `read(provider:)`, and `delete(provider:)` temporarily for AI providers and migration safety.

- [ ] **Step 5: Run schema test**

Run:

```bash
xcodebuild test -project MyTeam/MyTeam.xcodeproj -scheme MyTeamTests -configuration Debug -destination 'platform=macOS' -only-testing:MyTeamTests/CredentialSchemaTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add MyTeam/ProviderCredential.swift MyTeam/SecureCredentialStore.swift MyTeamTests/CredentialSchemaTests.swift
git commit -m "feat(credentials): add provider credential schemas"
```

## Task 2: Schema-Driven Connection Card UI

**Files:**
- Modify: `MyTeam/ConnectorSetupCardView.swift`
- Test: `MyTeamTests/CredentialSchemaTests.swift`

- [ ] **Step 1: Extend tests for Naver completeness**

Add:

```swift
func testNaverNewsRequiresAllFieldsBeforeStoredState() {
    let schema = ExternalProvider.naverNews.credentialSchema
    XCTAssertEqual(schema.fields.count, 2)
    XCTAssertEqual(schema.fields.map(\.id), ["clientID", "clientSecret"])
}
```

- [ ] **Step 2: Update card state to hold field values**

Replace `@State private var inputKey: String = ""` with:

```swift
@State private var inputValues: [String: String] = [:]
```

Add:

```swift
private var schema: ProviderCredentialSchema {
    provider.credentialSchema
}

private var canSaveInput: Bool {
    schema.fields.allSatisfy { field in
        !(inputValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

- [ ] **Step 3: Render one field per schema field**

Replace the single `SecureField("API 키 붙여넣기", text: $inputKey)` row with:

```swift
ForEach(schema.fields) { field in
    HStack(spacing: 8) {
        Text(field.label)
            .font(.system(size: 10, weight: .medium))
            .frame(width: 92, alignment: .leading)

        SecureField(field.placeholder, text: Binding(
            get: { inputValues[field.id] ?? "" },
            set: { inputValues[field.id] = $0 }
        ))
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 11, design: .monospaced))
    }
}
```

For non-secret fields, `TextField` can be used, but start with `SecureField` for all fields to avoid accidental disclosure. This is acceptable because Client ID is not sensitive enough to require display.

- [ ] **Step 4: Update save/delete**

Use:

```swift
private func saveKey() {
    guard canSaveInput else { return }
    for field in schema.fields {
        let value = inputValues[field.id] ?? ""
        SecureCredentialStore.shared.save(provider: provider, field: field, value: value)
    }
    CredentialHealthService.shared.didSaveKey(for: provider)
    inputValues = [:]
    isEditing = false
    testResultMessage = nil
}

private func deleteKey() {
    for field in schema.fields {
        SecureCredentialStore.shared.delete(provider: provider, field: field)
    }
    SecureCredentialStore.shared.delete(provider: provider)
    CredentialHealthService.shared.didDeleteKey(for: provider)
    testResultMessage = nil
}
```

- [ ] **Step 5: Run build**

Run:

```bash
xcodebuild build -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Debug -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add MyTeam/ConnectorSetupCardView.swift MyTeamTests/CredentialSchemaTests.swift
git commit -m "fix(settings): support multi-field provider credentials"
```

## Task 3: Direct Validators For Public APIs

**Files:**
- Modify: `MyTeam/SecureCredentialStore.swift`
- Create: `MyTeam/PublicAPIConnectorValidator.swift`
- Test: `MyTeamTests/PublicAPIConnectorValidatorTests.swift`

- [ ] **Step 1: Write validator tests with URLProtocol stubs**

```swift
import XCTest
@testable import MyTeam

final class PublicAPIConnectorValidatorTests: XCTestCase {
    func testNaverNewsValidationUsesClientHeaders() async throws {
        let request = PublicAPIValidationRequest(
            provider: .naverNews,
            fields: ["clientID": "id-123", "clientSecret": "secret-456"]
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertEqual(built.url?.host, "openapi.naver.com")
        XCTAssertEqual(built.value(forHTTPHeaderField: "X-Naver-Client-Id"), "id-123")
        XCTAssertEqual(built.value(forHTTPHeaderField: "X-Naver-Client-Secret"), "secret-456")
        XCTAssertTrue(built.url?.absoluteString.contains("/v1/search/news.json") ?? false)
    }

    func testDARTValidationUsesCrtfcKeyQuery() throws {
        let request = PublicAPIValidationRequest(
            provider: .dartDisclosure,
            fields: ["apiKey": "dart-key"]
        )

        let built = try PublicAPIConnectorValidator.makeRequest(for: request)

        XCTAssertTrue(built.url?.absoluteString.contains("crtfc_key=dart-key") ?? false)
    }
}
```

- [ ] **Step 2: Create validator request and request builder**

```swift
import Foundation

struct PublicAPIValidationRequest: Sendable {
    let provider: ExternalProvider
    let fields: [String: String]
}

enum PublicAPIConnectorValidator {
    static func makeRequest(for request: PublicAPIValidationRequest) throws -> URLRequest {
        switch request.provider {
        case .naverNews:
            guard
                let clientID = request.fields["clientID"], !clientID.isEmpty,
                let clientSecret = request.fields["clientSecret"], !clientSecret.isEmpty,
                let url = URL(string: "https://openapi.naver.com/v1/search/news.json?query=MyTeam&display=1&start=1&sort=date")
            else {
                throw ConnectorFailureCode.missingAPIKey
            }
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(clientID, forHTTPHeaderField: "X-Naver-Client-Id")
            urlRequest.setValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")
            return urlRequest

        case .dartDisclosure:
            guard let apiKey = request.fields["apiKey"], !apiKey.isEmpty else {
                throw ConnectorFailureCode.missingAPIKey
            }
            let urlString = "https://opendart.fss.or.kr/api/list.json?crtfc_key=\(apiKey)&bgn_de=20250101&page_no=1&page_count=1"
            guard let url = URL(string: urlString) else {
                throw ConnectorFailureCode.responseParseFailed
            }
            return URLRequest(url: url)

        case .kmaWeather:
            guard let serviceKey = request.fields["serviceKey"], !serviceKey.isEmpty else {
                throw ConnectorFailureCode.missingAPIKey
            }
            let urlString = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst?serviceKey=\(serviceKey)&numOfRows=1&pageNo=1&dataType=JSON&base_date=20250101&base_time=0600&nx=60&ny=127"
            guard let url = URL(string: urlString) else {
                throw ConnectorFailureCode.responseParseFailed
            }
            return URLRequest(url: url)

        case .openAI, .gemini, .anthropic, .openRouter:
            throw ConnectorFailureCode.providerUnavailable
        }
    }
}
```

- [ ] **Step 3: Add async validation**

```swift
static func validate(_ request: PublicAPIValidationRequest, session: URLSession = .shared) async -> CredentialTestResult {
    do {
        let urlRequest = try makeRequest(for: request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            return CredentialTestResult(provider: request.provider, success: false, failureCode: .networkError, message: "응답을 확인하지 못했습니다.")
        }
        if (200..<300).contains(http.statusCode) {
            return CredentialTestResult(provider: request.provider, success: true, failureCode: nil, message: "\(request.provider.displayName) 실제 연결 확인을 통과했습니다.")
        }
        return CredentialTestResult(provider: request.provider, success: false, failureCode: failureCode(status: http.statusCode, data: data), message: "\(request.provider.displayName) 연결 확인에 실패했습니다.")
    } catch let code as ConnectorFailureCode {
        return CredentialTestResult(provider: request.provider, success: false, failureCode: code, message: code.userMessage(for: request.provider))
    } catch {
        return CredentialTestResult(provider: request.provider, success: false, failureCode: .networkError, message: error.localizedDescription)
    }
}
```

- [ ] **Step 4: Route data providers through the validator**

In `SecureCredentialStore.testConnection(provider:)`, before `llmProviderRawValue`, add:

```swift
if [.naverNews, .dartDisclosure, .kmaWeather].contains(provider) {
    let fields = Dictionary(uniqueKeysWithValues: provider.credentialSchema.fields.map { field in
        (field.id, read(provider: provider, field: field) ?? "")
    })
    return await PublicAPIConnectorValidator.validate(
        PublicAPIValidationRequest(provider: provider, fields: fields)
    )
}
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -project MyTeam/MyTeam.xcodeproj -scheme MyTeamTests -configuration Debug -destination 'platform=macOS'
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add MyTeam/SecureCredentialStore.swift MyTeam/PublicAPIConnectorValidator.swift MyTeamTests/PublicAPIConnectorValidatorTests.swift
git commit -m "feat(connectors): validate BYOK public API credentials"
```

## Task 4: Connection Center Truth Copy

**Files:**
- Modify: `MyTeam/ConnectionCenterView.swift`
- Modify: `MyTeam/ConnectorSetupCardView.swift`

- [ ] **Step 1: Add execution mode model**

Add to `ProviderCredential.swift`:

```swift
enum ConnectorExecutionMode: String, Sendable {
    case byokDirect
    case proxyPlanned
}

extension ExternalProvider {
    var executionModes: [ConnectorExecutionMode] {
        switch self {
        case .kmaWeather, .naverNews, .dartDisclosure:
            return [.byokDirect, .proxyPlanned]
        case .openAI, .gemini, .anthropic, .openRouter:
            return [.byokDirect]
        }
    }
}
```

- [ ] **Step 2: Add honest mode labels in `ConnectorSetupCardView`**

Show:

```swift
Text("개인 키 연결 가능")
    .font(.system(size: 9, weight: .semibold))

if provider.executionModes.contains(.proxyPlanned) {
    Text("기본 조회 준비 중")
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
}
```

Do not show "기본 조회 가능".

- [ ] **Step 3: Run grep**

```bash
rg -n "기본 조회 가능|connected|사용 가능|키 저장됨|기본 조회 준비 중|개인 키 연결 가능" MyTeam --glob "*.swift"
```

Expected: no "기본 조회 가능"; `connected` only in state model or unrelated OAuth surfaces.

- [ ] **Step 4: Commit**

```bash
git add MyTeam/ProviderCredential.swift MyTeam/ConnectorSetupCardView.swift MyTeam/ConnectionCenterView.swift
git commit -m "fix(settings): separate BYOK direct from planned proxy"
```

## Task 5: Backlog Proxy Follow-Up

**Files:**
- Modify: `docs/backlog/myteam_product_backlog.json`

- [ ] **Step 1: Add P1 backlog task**

Add one task:

```json
{
  "id": "P1-public-api-proxy-architecture",
  "priority": "P1",
  "status": "todo",
  "category": "architecture",
  "title": "Public API proxy architecture",
  "why": "BYOK direct is the first shipping path. A future MyTeam proxy can provide limited default lookups, but only after quota, rate limit, privacy, billing, and health checks exist.",
  "acceptance_criteria": [
    "Proxy mode cannot display available without deployed endpoint health",
    "Naver upstream Client ID/Secret are server-held only",
    "Daily quota/rate limit policy documented",
    "No user query/result permanent storage unless explicitly disclosed"
  ],
  "completion_evidence": {
    "required": true,
    "commit_sha": "",
    "files_changed": [],
    "validation_summary": "",
    "screenshots": []
  },
  "notes": [
    "Do not build proxy in the BYOK direct PR."
  ]
}
```

- [ ] **Step 2: Run backlog validator**

```bash
python3 -m json.tool docs/backlog/myteam_product_backlog.json >/dev/null
python3 scripts/validate_release_checklist.py
```

Expected: both pass.

- [ ] **Step 3: Commit**

```bash
git add docs/backlog/myteam_product_backlog.json
git commit -m "docs(backlog): track public API proxy follow-up"
```

## Task 6: Naver News Runtime Source

**Files:**
- Create: `MyTeam/NaverNewsSearchConnector.swift`
- Modify: `MyTeam/KSkillAssistRuntime.swift`
- Test: `MyTeamTests/NaverNewsSearchConnectorTests.swift`

- [ ] **Step 1: Add connector result model**

```swift
struct NaverNewsSearchItem: Equatable, Sendable {
    let title: String
    let description: String
    let link: URL
    let originalLink: URL?
    let publishedAt: Date?
}
```

- [ ] **Step 2: Normalize HTML and dates**

```swift
enum NaverNewsSearchConnector {
    static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 3: Test cleanup**

```swift
func testCleanRemovesNaverHighlightAndEntities() {
    XCTAssertEqual(
        NaverNewsSearchConnector.clean("<b>삼성전자</b> &amp; AI"),
        "삼성전자 & AI"
    )
}
```

- [ ] **Step 4: Gate runtime use on validated credentials**

Only use direct Naver News when `CredentialHealthService.shared.health(for: .naverNews).state.isConnected` is true. Otherwise keep current assist-only message asking for links/body.

- [ ] **Step 5: Run tests and build**

```bash
xcodebuild test -project MyTeam/MyTeam.xcodeproj -scheme MyTeamTests -configuration Debug -destination 'platform=macOS'
xcodebuild build -project MyTeam/MyTeam.xcodeproj -scheme MyTeam -configuration Release -destination 'platform=macOS'
```

Expected: tests and Release build pass.

- [ ] **Step 6: Commit**

```bash
git add MyTeam/NaverNewsSearchConnector.swift MyTeam/KSkillAssistRuntime.swift MyTeamTests/NaverNewsSearchConnectorTests.swift
git commit -m "feat(kskills): use validated Naver News direct search"
```

## Task 7: Installed Skill Korean Descriptions

**Files:**
- Create: `docs/skills/installed_skills_ko.md`
- Optional later: user-approved patch script for `~/.codex/skills/**/SKILL.md` and `~/.agents/skills/**/SKILL.md`

- [ ] **Step 1: Generate a Korean catalog, not destructive metadata edits**

Run:

```bash
python3 scripts/generate_skill_description_catalog.py
```

Expected: `docs/skills/installed_skills_ko.md` lists installed skill names and Korean descriptions.

- [ ] **Step 2: Only if explicitly approved, patch global skill frontmatter**

Do not edit auto-generated gstack skill files by default. They contain `<!-- AUTO-GENERATED -->` and may be regenerated. Patching them globally can change routing and will not necessarily update the current Codex session.

## Test Diagram

```
CODE PATH COVERAGE
==================
[+] ProviderCredential.swift
    |
    ├── [GAP] credentialSchema for AI single-field providers
    ├── [GAP] credentialSchema for Naver multi-field provider
    ├── [GAP] credentialSchema for DART API Key
    └── [GAP] credentialSchema for KMA Service Key

[+] SecureCredentialStore.swift
    |
    ├── [GAP] save/read/delete field-specific Keychain values
    ├── [GAP] hasAllRequiredFields handles partial Naver credentials
    ├── [GAP] direct public API validator dispatch
    └── [GAP] saved-only state never becomes connected

[+] ConnectorSetupCardView.swift
    |
    ├── [GAP] renders two fields for Naver
    ├── [GAP] save disabled until all fields are filled
    ├── [GAP] delete clears all provider fields
    └── [GAP] proxy planned copy never says available

[+] PublicAPIConnectorValidator.swift
    |
    ├── [GAP] Naver request includes Client ID/Secret headers
    ├── [GAP] DART request uses crtfc_key
    ├── [GAP] KMA request uses serviceKey
    ├── [GAP] 401/403 maps to invalid/permission errors
    ├── [GAP] 429 maps to quota/rate limited
    └── [GAP] 5xx/parse errors do not become connected

USER FLOW COVERAGE
==================
[+] Connection Center
    |
    ├── [GAP] user enters only Naver Client ID, cannot save as complete
    ├── [GAP] user enters Client ID + Secret, sees stored-not-connected until validation
    ├── [GAP] fake Naver key validation fails visibly
    ├── [GAP] valid Naver key validation shows 사용 가능
    ├── [GAP] DART/KMA key entry remains enabled
    └── [GAP] no proxy available copy appears

COVERAGE: 0/25 new paths tested before implementation
TARGET: 25/25 via unit tests + manual Settings walkthrough
```

## Failure Modes

- Naver Client ID saved without Secret: test should keep provider not connected, UI should require all fields.
- Naver API permission not enabled: validator maps 403 to permission error, user sees key permission problem.
- Naver quota exceeded: validator maps 429, no retry loop.
- DART key invalid: validator fails, never connected.
- KMA service key URL encoding issue: validator must encode query values, otherwise false negative.
- Proxy unavailable: UI says "기본 조회 준비 중", not "가능".
- Current skill metadata patch breaks routing: avoid direct global skill edits unless explicitly approved.

## Sources

- Naver official docs: `https://developers.naver.com/docs/serviceapi/search/news/news.md`
- OpenDART guide: `https://opendart.fss.or.kr/guide/main.do?apiGrpCd=DS001`
- KMA/Data.go.kr service page: `https://www.data.go.kr/tcs/dss/selectApiDataDetailView.do?publicDataPk=15084084`
- k-skill Naver News skill: `https://raw.githubusercontent.com/NomaDamas/k-skill/main/naver-news-search/SKILL.md`

## Execution Recommendation

Implement Tasks 1-5 first. Task 6 should wait until direct validators are passing, because runtime search without a validated credential would recreate the exact fake-success problem we just cleaned up.
