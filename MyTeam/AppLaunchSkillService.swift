import Foundation

enum AppLaunchSkillService {
    static func detectSkillType(from message: String) -> AppLaunchSkillType? {
        let lower = message.lowercased()

        if containsAny(lower, [
            "앱스토어", "app store", "소개문", "설명문", "메타데이터", "subtitle", "promotional text"
        ]) {
            return .appStoreCopy
        }

        if containsAny(lower, [
            "온보딩", "첫 화면", "튜토리얼", "시작 문구", "welcome", "onboarding"
        ]) {
            return .onboardingCopy
        }

        if containsAny(lower, [
            "출시 체크리스트", "앱 출시 준비", "배포 전 점검", "심사 준비", "launch checklist"
        ]) {
            return .launchChecklist
        }

        if containsAny(lower, [
            "수익화 점검표", "수익화 리뷰", "수익화 전략", "bm 점검", "비즈니스 모델 점검", "monetization review", "monetization checklist"
        ]) {
            return .monetizationReview
        }

        return nil
    }

    static func extractRequest(from message: String, skillType: AppLaunchSkillType) -> AppLaunchSkillRequest {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let appName = extractAppName(from: trimmed, skillType: skillType) ?? ""
        let appCategory = extractCategory(from: trimmed)
        let targetUser = extractTargetUser(from: trimmed)
        let coreFeatures = extractCoreFeatures(from: trimmed)
        let monetizationModel = extractMonetizationModel(from: trimmed)
        let tone = extractTone(from: trimmed)
        let notes = trimmed.isEmpty ? nil : trimmed

        return AppLaunchSkillRequest(
            skillType: skillType,
            appName: appName,
            appCategory: appCategory,
            targetUser: targetUser,
            coreFeatures: coreFeatures,
            monetizationModel: monetizationModel,
            tone: tone,
            notes: notes
        )
    }

    static func needsMoreInfo(_ request: AppLaunchSkillRequest) -> [String] {
        request.appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ["앱 이름"] : []
    }

    static func buildPrompt(_ request: AppLaunchSkillRequest) -> String {
        let featureLines = request.coreFeatures.isEmpty
            ? "- 핵심 기능: (사용자 설명을 바탕으로 자연스럽게 보강)"
            : request.coreFeatures.map { "- \($0)" }.joined(separator: "\n")

        let categoryLine = request.appCategory.map { "앱 카테고리: \($0)" } ?? "앱 카테고리: 미지정"
        let userLine = request.targetUser.map { "타깃 사용자: \($0)" } ?? "타깃 사용자: 미지정"
        let monetizationLine = request.monetizationModel.map { "수익화 모델: \($0)" } ?? "수익화 모델: 미지정"
        let toneLine = request.tone.map { "톤: \($0)" } ?? "톤: 간결하고 출시 준비용"
        let noteBlock = request.notes.map { "\n추가 메모:\n\($0)" } ?? ""

        let sectionInstructions: String
        switch request.skillType {
        case .appStoreCopy:
            sectionInstructions = """
            # \(request.appName) 앱스토어 설명문 초안
            ## 한 줄 소개
            ## Subtitle 후보
            ## Promotional Text 후보
            ## Description
            ## 주요 기능
            ## 추천 키워드
            ## 스크린샷 캡션 후보
            ## 심사 전 확인사항
            """
        case .onboardingCopy:
            sectionInstructions = """
            # \(request.appName) 온보딩 문구 초안
            ## 3-step 온보딩
            ## 첫 실행 환영 문구
            ## 권한 요청 전 안내문
            ## 빈 상태 문구
            ## CTA 버튼 문구
            """
        case .launchChecklist:
            sectionInstructions = """
            # \(request.appName) 출시 체크리스트
            ## 앱스토어 메타데이터
            ## 개인정보/약관
            ## 분석/광고/결제 SDK
            ## 권한 문구
            ## 테스트
            ## 심사 제출
            ## 출시 후 모니터링
            """
        case .monetizationReview:
            sectionInstructions = """
            # \(request.appName) 수익화 점검표
            ## 현재 BM 가정
            ## 광고
            ## 구독
            ## 인앱결제
            ## 가격 실험
            ## 무료/Pro 경계
            ## BYOK 정책
            ## 리스크
            ## 다음 액션
            """
        }

        return """
        당신은 MyTeam의 앱 출시 준비 문서를 작성합니다.
        외부 API, 웹 검색, App Store Connect 호출 없이, 제공된 정보만으로 한국어 Markdown 초안을 작성하세요.
        출력은 Markdown 본문만 작성하고 코드펜스는 쓰지 마세요.

        \(sectionInstructions)

        \(categoryLine)
        \(userLine)
        \(monetizationLine)
        \(toneLine)
        핵심 기능:
        \(featureLines)
        \(noteBlock)

        문서 하단에는 반드시 아래 안전 문구를 한 줄 추가하세요.
        "본 문서는 출시 준비용 초안입니다. 실제 앱 구조, 플랫폼 정책, 심사 기준에 맞게 수정해야 합니다."
        """
    }

    static func outputFilename(_ request: AppLaunchSkillRequest) -> String {
        let base = sanitized(request.appName)
        return "\(base)_\(request.skillType.defaultFilenameSuffix).md"
    }

    static func questionMessage(for skillType: AppLaunchSkillType) -> String {
        """
        앱 출시 문서를 만들려면 앱 이름이 필요합니다.

        예:
        IMMM \(skillType.displayName) 만들어줘. 20대용 포토부스 앱이고, 4컷 사진과 프레임 꾸미기가 핵심이야.
        """
    }

    private static func containsAny(_ lower: String, _ keywords: [String]) -> Bool {
        keywords.contains { lower.contains($0) }
    }

    private static func extractAppName(from message: String, skillType: AppLaunchSkillType) -> String? {
        let explicitNameMarkers = ["앱 이름은", "앱명은", "앱 이름:", "앱명:", "이름은", "이름:"]

        for marker in explicitNameMarkers {
            if let range = message.range(of: marker, options: .caseInsensitive) {
                let suffix = message[range.upperBound...]
                if let candidate = firstMeaningfulToken(from: String(suffix)) {
                    return candidate
                }
            }
        }

        for keyword in skillTypeKeywords(skillType) {
            if let range = message.range(of: keyword, options: .caseInsensitive) {
                let prefix = message[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                if let candidate = lastMeaningfulToken(from: prefix) {
                    return candidate
                }
                if let candidate = firstMeaningfulToken(from: prefix) {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func skillTypeKeywords(_ skillType: AppLaunchSkillType) -> [String] {
        switch skillType {
        case .appStoreCopy:
            return ["앱스토어", "app store", "소개문", "설명문", "메타데이터", "subtitle", "promotional text"]
        case .onboardingCopy:
            return ["온보딩", "첫 화면", "튜토리얼", "시작 문구", "welcome", "onboarding"]
        case .launchChecklist:
            return ["출시 체크리스트", "앱 출시 준비", "배포 전 점검", "심사 준비", "launch checklist"]
        case .monetizationReview:
            return ["수익화 점검표", "수익화 리뷰", "수익화 전략", "bm 점검", "비즈니스 모델 점검", "monetization review", "monetization checklist"]
        }
    }

    private static func firstMeaningfulToken(from text: String) -> String? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":-,，。.!?"))
        guard !cleaned.isEmpty else { return nil }
        let words = cleaned.split(whereSeparator: { $0.isWhitespace || ":-,，。.!?".contains($0) }).map(String.init)
        for word in words {
            if let candidate = sanitizeCandidate(word) {
                return candidate
            }
        }
        return nil
    }

    private static func lastMeaningfulToken(from text: String) -> String? {
        let words = text
            .split(whereSeparator: { $0.isWhitespace || ":-,，。.!?".contains($0) })
            .map(String.init)
        for word in words.reversed() {
            if let candidate = sanitizeCandidate(word) {
                return candidate
            }
        }
        return nil
    }

    private static func sanitizeCandidate(_ value: String) -> String? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = ["이라는", "라는", "앱의", "어플의", "서비스의", "이고", "이며", "입니다", "이에요", "예요", "인데", "이고요"]
        for suffix in suffixes where trimmed.hasSuffix(suffix) {
            trimmed.removeLast(suffix.count)
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard trimmed.count >= 2 else { return nil }
        let noise = ["앱스토어", "설명문", "온보딩", "체크리스트", "수익화", "문구", "만들어줘", "작성해줘", "앱", "어플", "앱명", "이름", "문서", "초안"]
        guard !noise.contains(where: { trimmed.contains($0) }) else { return nil }
        return trimmed
    }

    private static func extractCategory(from message: String) -> String? {
        let lower = message.lowercased()
        let categories = ["포토부스", "생산성", "헬스", "교육", "금융", "쇼핑", "콘텐츠", "커뮤니티", "도구", "업무", "여행", "게임"]
        return categories.first { lower.contains($0) }
    }

    private static func extractTargetUser(from message: String) -> String? {
        let lower = message.lowercased()
        let audiences = ["20대", "30대", "직장인", "대학생", "초보자", "전문가", "창업자", "팀", "개인"]
        if let audience = audiences.first(where: { lower.contains($0) }) {
            return audience
        }
        return nil
    }

    private static func extractCoreFeatures(from message: String) -> [String] {
        let lower = message.lowercased()
        let features = ["프레임", "사진", "촬영", "꾸미기", "편집", "구독", "광고", "공유", "저장", "협업", "리뷰", "알림"]
        return features.filter { lower.contains($0) }
    }

    private static func extractMonetizationModel(from message: String) -> String? {
        let lower = message.lowercased()
        if lower.contains("구독") { return "구독" }
        if lower.contains("광고") { return "광고" }
        if lower.contains("인앱결제") || lower.contains("in-app") { return "인앱결제" }
        if lower.contains("byok") { return "BYOK" }
        return nil
    }

    private static func extractTone(from message: String) -> String? {
        let lower = message.lowercased()
        let tones = ["친근", "전문", "간결", "감성", "세련", "명확", "짧게", "따뜻", "신뢰"]
        return tones.first { lower.contains($0) }
    }

    private static func sanitized(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: " _-"))
        let mapped = cleaned.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let collapsed = String(mapped).replacingOccurrences(of: " ", with: "_")
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "app" : trimmed
    }
}
