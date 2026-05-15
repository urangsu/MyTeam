import Foundation

enum CharacterIDNormalizer: Sendable {
    static func canonicalID(_ rawID: String) -> String {
        let lowered = rawID.lowercased()

        if lowered == "chiko" || lowered.hasSuffix(".chiko") { return "chiko" }
        if lowered == "sena" || lowered.hasSuffix(".sena") { return "sena" }
        if lowered == "kai" || lowered.hasSuffix(".kai") { return "kai" }
        if lowered == "yuna" || lowered.hasSuffix(".yuna") { return "yuna" }

        if lowered == "leo" || lowered.hasSuffix(".leo") { return "leo" }
        if lowered == "luna" || lowered.hasSuffix(".luna") { return "luna" }
        if lowered == "moko" || lowered.hasSuffix(".moko") { return "moko" }
        if lowered == "rex" || lowered.hasSuffix(".rex") { return "rex" }
        if lowered == "kei" || lowered.hasSuffix(".kei") { return "kei" }
        if lowered == "lucky" || lowered.hasSuffix(".lucky") { return "lucky" }
        if lowered == "pola" || lowered.hasSuffix(".pola") { return "pola" }
        if lowered == "mongmong" || lowered.hasSuffix(".mongmong") { return "mongmong" }
        if lowered == "oliver" || lowered.hasSuffix(".oliver") { return "oliver" }
        if lowered == "pin" || lowered.hasSuffix(".pin") { return "pin" }

        return lowered
    }
}

enum CharacterCatalog {
    static let builtIn: [CharacterDLC] = [
        makeBuiltIn(id: "leo", agentID: "agent_1", name: "레오", subtitle: "시장과 수익 구조를 먼저 보는 전략가", portrait: "레오_profile", sprite: "leo_placeholder", bundledSkillIDs: ["korean.weather", "korean.dart"]),
        makeBuiltIn(id: "luna", agentID: "agent_2", name: "루나", subtitle: "캠페인 감각이 빠른 콘텐츠 메이커", portrait: "루나_profile", sprite: "luna_placeholder", bundledSkillIDs: ["korean.naver-news", "korean.naver-blog-research"]),
        makeBuiltIn(id: "moko", agentID: "agent_3", name: "모코", subtitle: "일정을 정리하고 우선순위를 잡는 PM", portrait: "모코_profile", sprite: "moko_placeholder", bundledSkillIDs: ["korean.weather"]),
        makeBuiltIn(id: "rex", agentID: "agent_6", name: "렉스", subtitle: "규제와 리스크를 먼저 보는 법률 검토자", portrait: "렉스_profile", sprite: "rex_placeholder", bundledSkillIDs: ["korean.law-search"]),
        makeBuiltIn(id: "chiko", agentID: "agent_5", name: "치코", subtitle: "사용자 흐름을 집요하게 보는 UX 메이트", portrait: "치코_profile", sprite: "치코", bundledSkillIDs: ["korean.naver-blog-research"]),
        makeBuiltIn(id: "kei", agentID: "agent_7", name: "케이", subtitle: "로그와 권한 경계를 따지는 보안 분석가", portrait: "케이_profile", sprite: "kei_placeholder", bundledSkillIDs: ["korean.dart"]),
        makeBuiltIn(id: "lucky", agentID: "agent_8", name: "래키", subtitle: "API와 서버 병목을 파고드는 백엔드 메이트", portrait: "래키_profile", sprite: "lucky_placeholder", bundledSkillIDs: ["korean.hwp-read"]),
        makeBuiltIn(id: "pola", agentID: "agent_9", name: "폴라", subtitle: "거래 구조와 제안을 정리하는 BD 파트너", portrait: "폴라_profile", sprite: "pola_placeholder", bundledSkillIDs: ["korean.naver-news"]),
        makeBuiltIn(id: "mongmong", agentID: "agent_10", name: "몽몽", subtitle: "공감과 응대를 챙기는 CS 메이트", portrait: "몽몽_profile", sprite: "mongmong_placeholder", bundledSkillIDs: ["korean.weather"]),
        makeBuiltIn(id: "oliver", agentID: "agent_11", name: "올리버", subtitle: "엣지 케이스를 집요하게 찾는 QA 엔지니어", portrait: "올리버_profile", sprite: "oliver_placeholder", bundledSkillIDs: ["korean.hwp-read"]),
        makeBuiltIn(id: "pin", agentID: "agent_4", name: "핀", subtitle: "시각 밀도를 다듬는 UI 디자이너", portrait: "핀_profile", sprite: "pin_placeholder", bundledSkillIDs: ["korean.naver-blog-research"])
    ]

    static let premium: [CharacterDLC] = [
        CharacterDLC(
            id: "char.premium.sena",
            agentID: nil,
            name: "세나",
            subtitle: "앱 출시 문구와 정책을 마감까지 끌고 가는 PM",
            role: "앱 출시 PM",
            description: "앱스토어 출시, 약관 초안, 온보딩 문구, 수익화 포인트를 한 흐름으로 정리하는 출시 전용 캐릭터.",
            specialty: ["앱스토어 출시", "개인정보처리방침", "이용약관", "수익화", "온보딩 문구"],
            personaPrompt: "너의 이름은 세나야. 너는 앱 출시 PM 역할을 수행해. 출시 체크리스트, 정책 문구, 온보딩 문장, 수익화 구조를 현실적으로 정리하고 마감 기준으로 우선순위를 세운다.",
            spriteAssetName: "sena_placeholder",
            portraitAssetName: "세나_profile",
            previewVoiceAssetName: "세나_preview",
            bundledSkillIDs: ["korean.privacy-terms"],
            recommendedProvider: "openai",
            productID: ProductIDCatalog.Character.sena,
            priceDisplay: "₩3,900",
            isBuiltIn: false,
            isPremium: true,
            isComingSoon: true
        ),
        CharacterDLC(
            id: "char.premium.kai",
            agentID: nil,
            name: "카이",
            subtitle: "구조와 품질을 같이 보는 Swift 아키텍트",
            role: "코드 리뷰 아키텍트",
            description: "코드 리뷰, 구조 점검, 성능 병목, macOS/Swift 구현 품질을 함께 보는 기술 전용 캐릭터.",
            specialty: ["코드 리뷰", "아키텍처", "성능 개선", "Swift/macOS"],
            personaPrompt: "너의 이름은 카이야. 너는 코드 리뷰 아키텍트 역할을 수행해. 구조적 결함, 리스크, 성능 병목, macOS 구현 품질을 짧고 명확하게 지적하고 개선안을 제시한다.",
            spriteAssetName: "kai_placeholder",
            portraitAssetName: "카이_profile",
            previewVoiceAssetName: "카이_preview",
            bundledSkillIDs: ["korean.hwp-read"],
            recommendedProvider: "claude",
            productID: ProductIDCatalog.Character.kai,
            priceDisplay: "₩3,900",
            isBuiltIn: false,
            isPremium: true,
            isComingSoon: true
        ),
        CharacterDLC(
            id: "char.premium.yuna",
            agentID: nil,
            name: "유나",
            subtitle: "블로그, SEO, 썸네일까지 묶어서 보는 콘텐츠 전략가",
            role: "콘텐츠 전략가",
            description: "네이버 블로그 운영, SEO 키워드, 발행 캘린더, 썸네일 문구까지 묶어서 잡는 콘텐츠 전용 캐릭터.",
            specialty: ["네이버 블로그", "SEO", "썸네일 문구", "콘텐츠 캘린더"],
            personaPrompt: "너의 이름은 유나야. 너는 콘텐츠 전략가 역할을 수행해. 네이버 블로그와 SEO 관점에서 제목, 키워드, 썸네일 문구, 발행 리듬을 실무형으로 제안한다.",
            spriteAssetName: "yuna_placeholder",
            portraitAssetName: "유나_profile",
            previewVoiceAssetName: "유나_preview",
            bundledSkillIDs: ["korean.naver-blog-research", "korean.naver-news"],
            recommendedProvider: "gemini",
            productID: ProductIDCatalog.Character.yuna,
            priceDisplay: "₩3,900",
            isBuiltIn: false,
            isPremium: true,
            isComingSoon: true
        )
    ]

    static var all: [CharacterDLC] { builtIn + premium }

    static func character(id: String) -> CharacterDLC? {
        all.first { $0.id == id }
    }

    static func validateBuiltInAgentMappings() {
        for character in builtIn {
            guard let agentID = character.agentID else {
                AppLog.warning("[CharacterCatalog] missing agentID for \(character.id)")
                continue
            }

            guard let persona = agentPersonas[agentID] else {
                AppLog.warning("[CharacterCatalog] invalid agentID \(agentID) for \(character.name)")
                continue
            }

            if persona.name != character.name {
                AppLog.warning("[CharacterCatalog] name mismatch \(character.name) ↔︎ \(persona.name)")
            }
        }
    }

    private static func makeBuiltIn(
        id: String,
        agentID: String?,
        name: String,
        subtitle: String,
        portrait: String,
        sprite: String,
        bundledSkillIDs: [String]
    ) -> CharacterDLC {
        let persona = personaForBuiltIn(name: name)
        return CharacterDLC(
            id: "char.builtin.\(id)",
            agentID: agentID,
            name: name,
            subtitle: subtitle,
            role: persona.role,
            description: "\(name)은 MyTeam 기본 제공 캐릭터로, \(persona.specialty) 영역에서 바로 대화에 참여할 수 있는 팀원입니다.",
            specialty: persona.specialty
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            personaPrompt: persona.persona,
            spriteAssetName: sprite,
            portraitAssetName: portrait,
            previewVoiceAssetName: nil,
            bundledSkillIDs: bundledSkillIDs,
            recommendedProvider: nil,
            productID: nil,
            priceDisplay: nil,
            isBuiltIn: true,
            isPremium: false,
            isComingSoon: false
        )
    }

    private static func personaForBuiltIn(name: String) -> AgentPersona {
        if let persona = agentPersonas.values.first(where: { $0.name == name }) {
            return persona
        }
        return AgentPersona(
            name: name,
            role: "팀원",
            persona: "\(name)은 MyTeam의 기본 캐릭터다.",
            specialty: "기본 협업"
        )
    }

    // MARK: - Asset-Aware Visibility Policy

    static func assetManifest(for characterID: String) -> CharacterAssetManifest {
        let canonical = CharacterIDNormalizer.canonicalID(characterID)

        switch canonical {
        case "chiko":
            return CharacterAssetManifest(
                characterID: "chiko",
                hasIdleSprite: true,
                hasThinkingSprite: false,
                hasWorkingSprite: true,
                hasSuccessSprite: true,
                hasSmallIcon: true,
                hasScreenshotPose: false,
                isPlaceholder: false,
                isDLCReady: false
            )
        default:
            return CharacterAssetManifest(
                characterID: canonical,
                hasIdleSprite: false,
                hasThinkingSprite: false,
                hasWorkingSprite: false,
                hasSuccessSprite: false,
                hasSmallIcon: false,
                hasScreenshotPose: false,
                isPlaceholder: true,
                isDLCReady: false
            )
        }
    }

    static func isVisibleInRelease(_ character: CharacterDLC) -> Bool {
        ReleaseVisibleCharacterPolicy.isVisibleInRelease(
            assetManifest(for: character.id)
        )
    }

    static func isPurchasableInRelease(_ character: CharacterDLC) -> Bool {
        ReleaseVisibleCharacterPolicy.isPurchasableInRelease(
            assetManifest(for: character.id)
        )
    }

    static func releaseVisibleCharacters() -> [CharacterDLC] {
        all.filter { isVisibleInRelease($0) }
    }

    static func releasePurchasableCharacters() -> [CharacterDLC] {
        all.filter { isPurchasableInRelease($0) }
    }

    static func releasePrimaryCharacter() -> CharacterDLC? {
        character(id: "char.builtin.chiko")
    }

    static let chikoDefaultExperienceCopy = "치코는 사용자 흐름을 집요하게 보는 UX 메이트로, MyTeam의 핵심 팀원입니다. 어떤 작업이든 사용자 관점으로 함께 검토해 드립니다."
}
