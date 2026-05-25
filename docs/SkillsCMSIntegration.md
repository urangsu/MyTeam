# K-Skills CMS Integration Guide

**Version:** 1.0  
**Status:** Ready for CMS Integration  
**Last Updated:** 2026-05-25

---

## Overview

K-Skills responses are now **100% externalized to JSON** (`MyTeam/Resources/skills.json`), enabling:
- ✅ Real-time response updates without code deployment
- ✅ Multi-language content management (Korean, English, Japanese)
- ✅ A/B testing and variant management
- ✅ Easy CMS integration (Strapi, Contentful, Sanity)
- ✅ Decoupling of content from application logic

---

## Architecture

### Current Flow
```
User Input
    ↓
KSkillAssistRuntime.detectIntent() [in-memory function]
    ↓
buildAssistResponse() [calls SkillResourceLoader]
    ↓
SkillResourceLoader.skill(for: skillID) [loads from skills.json]
    ↓
KSkillAssistCardView [renders response]
```

### JSON Structure
```
{
  "version": "1.0",
  "lastUpdated": "2026-05-25",
  "skills": {
    "transportation-booking": {
      "intent": "transportationBookingAssist",
      "title": "Transportation Booking Helper",
      "message": "...",
      "checklist": [...],
      "requiredInputs": [...],
      "nextActions": [...],
      "hardBlockedActions": [...],
      "keywords": {
        "ko": ["기차", "버스", "항공"],
        "en": ["train", "bus", "flight"],
        "ja": ["電車", "バス", "航空"]
      }
    }
  }
}
```

---

## Phase 1: Current State ✅

### Files
- `MyTeam/Resources/skills.json` — Master content source
- `MyTeam/SkillResourceLoader.swift` — JSON loader (bundle-based)
- `MyTeam/KSkillAssistRuntime.swift` — Intent detection (in-memory keywords)

### Loading Method
- **Source:** Bundle resource (offline-first)
- **Frequency:** App launch only
- **Update Method:** Code redeployment

---

## Phase 2: Local File Sync (1-2 weeks)

Prepare for real-time updates without redeployment.

### Implementation Steps

#### 2.1 Add SkillsCachePath
```swift
// SkillResourceLoader.swift additions
class SkillResourceLoader {
    static let cacheDirectory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first?.appendingPathComponent("Skills")

    func loadFromCache() -> SkillsResource? {
        guard let cacheDir = Self.cacheDirectory,
              let data = try? Data(contentsOf: cacheDir.appendingPathComponent("skills.json")) else {
            return nil
        }
        return try? JSONDecoder().decode(SkillsResource.self, from: data)
    }

    func saveToCache(_ resource: SkillsResource) throws {
        guard let cacheDir = Self.cacheDirectory else { return }
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(resource)
        try data.write(to: cacheDir.appendingPathComponent("skills.json"))
    }
}
```

#### 2.2 Load Priority
```
1. Check cache (documents/Skills/skills.json)
2. If no cache, load from bundle
3. Allow manual sync trigger
```

#### 2.3 Sync Endpoint
```
POST /api/skills/sync
Headers: Authorization: Bearer {token}
Response: { version: "1.0", checksum: "sha256:...", skills: {...} }
```

---

## Phase 3: CMS Integration (2-3 weeks)

Connect to Strapi, Contentful, or custom API.

### Option A: Strapi (Recommended for this phase)

#### 3.1 Strapi Content Type
```javascript
{
  kind: "collectionType",
  collectionName: "skills",
  attributes: {
    skillID: { type: "string", required: true, unique: true },
    intent: { type: "string", required: true },
    title: { type: "string", required: true },
    message: { type: "richtext" },
    checklist: { type: "array", component: "string" },
    requiredInputs: { type: "array", component: "string" },
    nextActions: { type: "array", component: "string" },
    hardBlockedActions: { type: "array", component: "string" },
    keywords: {
      type: "object",
      attributes: {
        ko: { type: "array", component: "string" },
        en: { type: "array", component: "string" },
        ja: { type: "array", component: "string" }
      }
    },
    publishedAt: { type: "datetime" }
  }
}
```

#### 3.2 App-Side: Strapi Loader
```swift
class StrapiSkillsLoader {
    let strapiURL: URL
    let apiToken: String

    func fetch() async throws -> SkillsResource {
        var request = URLRequest(url: strapiURL.appendingPathComponent("/api/skills"))
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StrapiResponse.self, from: data)

        return response.toSkillsResource()
    }

    func sync() async {
        do {
            let resource = try await fetch()
            try SkillResourceLoader.shared.saveToCache(resource)
        } catch {
            AppLog.error("[StrapiLoader] Sync failed: \(error)")
        }
    }
}
```

#### 3.3 Background Sync
```swift
// In AppDelegate or SceneDelegate
func applicationDidBecomeActive() {
    Task {
        await StrapiSkillsLoader(
            strapiURL: URL(string: "https://cms.example.com")!,
            apiToken: KeychainManager.retrieveToken()
        ).sync()
    }
}
```

---

### Option B: Contentful

#### 3.1 Content Model
```
Content Type: KSkill
- skillID (Short text, required, unique)
- intent (Short text, required)
- title (Short text, required)
- message (Long text / Rich text)
- checklist (Array of Short text)
- requiredInputs (Array of Short text)
- nextActions (Array of Short text)
- hardBlockedActions (Array of Short text)
- keywordsKo (Array of Short text)
- keywordsEn (Array of Short text)
- keywordsJa (Array of Short text)
```

#### 3.2 App-Side: Contentful Loader
```swift
class ContentfulSkillsLoader {
    let client: CDAClient

    func fetch() async throws -> SkillsResource {
        let query: [String: Any] = ["content_type": "kskill"]
        let entries = try await client.fetchEntriesMatching(query: query)

        var skills: [String: SkillData] = [:]
        for entry in entries {
            let skillData = try mapContentfulEntryToSkillData(entry)
            skills[entry.id] = skillData
        }

        return SkillsResource(version: "1.0", lastUpdated: ISO8601DateFormatter().string(from: Date()), skills: skills)
    }
}
```

---

## Phase 4: Multi-Language Management (3-4 weeks)

Support localized content per language.

### Directory Structure
```
resources/
├── skills-en.json     (English, master)
├── skills-ko.json     (Korean)
├── skills-ja.json     (Japanese)
└── _metadata.json     (version, checksums)
```

### Loader Enhancement
```swift
class MultiLanguageSkillsLoader {
    enum Language: String {
        case en, ko, ja
    }

    func load(language: Language = .en) -> SkillsResource? {
        let filename = "skills-\(language.rawValue).json"
        // ... load and decode
    }

    func currentLanguage() -> Language {
        // Detect from Locale or app preference
        switch Locale.current.languageCode {
        case "ko": return .ko
        case "ja": return .ja
        default: return .en
        }
    }
}
```

### CMS Side: Localization
**Strapi:** Use i18n plugin to manage Korean, English, Japanese variants  
**Contentful:** Use Locales feature

---

## Phase 5: Analytics & A/B Testing (4-6 weeks)

Track usage and test variants.

### Metrics to Track
```json
{
  "skillID": "transportation-booking",
  "eventType": "intent_detected",
  "userID": "uuid",
  "message": "Book my flight",
  "detectedConfidence": 0.92,
  "variant": "control",
  "timestamp": "2026-05-25T..."
}
```

### A/B Testing Schema
```json
{
  "skillID": "transportation-booking",
  "variants": {
    "control": {
      "message": "I don't handle booking...",
      "weight": 0.5
    },
    "variant_a": {
      "message": "Let me help you prepare...",
      "weight": 0.25
    },
    "variant_b": {
      "message": "I'll organize your booking checklist...",
      "weight": 0.25
    }
  },
  "experiment": "message-clarity-test",
  "startDate": "2026-05-25",
  "endDate": "2026-06-08"
}
```

---

## Migration Checklist

- [ ] **Phase 1 (✅ DONE):** JSON externalized, loader implemented
- [ ] **Phase 2:** Local file sync + manual trigger
- [ ] **Phase 3a:** Strapi setup + API integration
- [ ] **Phase 3b:** OR Contentful setup + API integration
- [ ] **Phase 4:** Multi-language content + loader
- [ ] **Phase 5:** Analytics pipeline + A/B testing UI

---

## Best Practices

### 1. Content Management
- Always test JSON syntax with `JSONLint.com` before sync
- Maintain version history in CMS
- Tag content changes with intent+version

### 2. Keyword Management
- Keep keywords conservative (2-3 per language)
- Avoid false positives (e.g., "stock" might trigger investment when user means "stockpile")
- Document keyword conflicts in CMS notes

### 3. Offline Safety
- Always cache most recent version
- Validate JSON before saving to cache
- Show cached version with "⚠️ Offline" badge

### 4. Rollback Strategy
```swift
// Keep previous version in cache
let previousResource = try? SkillResourceLoader.shared.loadFromCache()
let newResource = try SkillResourceLoader.shared.fetch()

if !newResource.isValid() {
    // Revert to previous
    SkillResourceLoader.shared.skills = previousResource.skills
    AppLog.warning("[SkillsLoader] Reverted to previous version")
}
```

---

## Example: Adding a New Skill to CMS

### Step 1: Create in Strapi
- Collection: Skills
- skillID: `restaurant-reservation`
- intent: `restaurantReservationAssist`
- title: "Restaurant Reservation Helper"
- message: "I don't make reservations..."
- keywords (en): ["restaurant", "booking", "table"]
- keywords (ko): ["레스토랑", "예약"]
- keywords (ja): ["レストラン", "予約"]

### Step 2: App Auto-Syncs
- Background sync detects new skill
- SkillResourceLoader caches locally
- Next app restart: intent detection includes keywords
- User says "book a table" → triggers `restaurantReservationAssist`

### Step 3: Monitor & Iterate
- Track intent detection confidence
- If accuracy > 90%, keep as default
- Run A/B test on message copy
- Update based on user feedback

---

## Troubleshooting

### JSON Invalid Error
```
[SkillResourceLoader] Failed to load skills.json: Swift.DecodingError
```
**Fix:** Validate JSON structure against schema

### Sync Fails
```
[StrapiLoader] Sync failed: URLError(Code: -1009)
```
**Fix:** Check network connectivity, Strapi API token validity

### Intent Not Detected
```
User: "I want to book a hotel"
Result: nil (no intent detected)
```
**Fix:** Add "hotel" to keywords in skills.json (accommodation-planning)

---

## CMS Vendor Comparison

| Feature | Strapi | Contentful | Sanity |
|---------|--------|-----------|--------|
| Self-hosted | ✅ Yes | ❌ No | ✅ Yes |
| Learning curve | Medium | Low | High |
| Localization | ✅ Plugin | ✅ Built-in | ✅ Built-in |
| Cost (small team) | Free | Free (up to 2 spaces) | Free |
| API Rate Limit | Unlimited | 1000/hr | Unlimited |
| **Recommendation** | 🎯 Best for MVP | Good for quick start | Complex scaling |

---

## Next: Implement Phase 2

1. Add cache directory + load priority logic
2. Create sync endpoint
3. Add manual "Refresh Skills" button in Settings
4. Test fallback when cache unavailable

Estimated time: 1-2 weeks
