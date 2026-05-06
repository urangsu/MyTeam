import Foundation

// MARK: - DocumentType
enum KoreanPrivacyDocumentType: String {
    case privacy = "privacy"
    case terms = "terms"
    case both = "both"
}

// MARK: - KoreanPrivacyTermsRequest
struct KoreanPrivacyTermsRequest: Equatable {
    let serviceName: String              // 필수 (nil/empty면 needsMoreInfo)
    let operatorName: String?            // 선택, TODO로 표시 가능
    let contactEmail: String?            // 선택, TODO로 표시 가능
    let serviceType: String?             // 모바일앱, 웹사이트 등
    let documentType: KoreanPrivacyDocumentType
    let collectsPersonalInfo: Bool        // 회원가입, 이름, 이메일 등
    let usesAnalytics: Bool              // Firebase GA 등
    let usesAds: Bool                    // AdMob, 배너광고 등
    let usesPayments: Bool               // 결제, 구독 등
    let handlesLocation: Bool            // GPS, 지도 등
    let targetsChildren: Bool            // 만 14세 미만 대상
    let notes: String?                   // 추가 설명
    let filename: String
}

// MARK: - KoreanPrivacyTermsService
enum KoreanPrivacyTermsService {

    /// 사용자 메시지에서 요청 데이터를 추출한다.
    /// serviceName이 없으면 nil을 반환 (needsMoreInfo 확인 필요).
    static func extractRequest(from message: String) -> KoreanPrivacyTermsRequest? {
        let lower = message.lowercased()

        // 문서 유형 판정
        let needsPrivacy = lower.contains("개인정보") || lower.contains("privacy") || lower.contains("정보처리방침")
        let needsTerms = lower.contains("약관") || lower.contains("terms") || lower.contains("이용약관") || lower.contains("서비스약관")

        guard needsPrivacy || needsTerms else { return nil }

        let documentType: KoreanPrivacyDocumentType = {
            if needsPrivacy && needsTerms { return .both }
            else if needsPrivacy { return .privacy }
            else { return .terms }
        }()

        // 서비스명 추출 (필수) — 기본값 금지
        guard let serviceName = extractServiceName(from: message), !serviceName.isEmpty else { return nil }

        // 운영자명, 이메일, 서비스 타입 추출
        let operatorName = extractOperatorName(from: message)
        let contactEmail = extractContactEmail(from: message)
        let serviceType = extractServiceType(from: message)

        // 기능별 플래그 추출
        let collectsPersonalInfo = detectPersonalInfoCollection(from: lower)
        let usesAnalytics = detectAnalytics(from: lower)
        let usesAds = detectAds(from: lower)
        let usesPayments = detectPayments(from: lower)
        let handlesLocation = detectLocation(from: lower)
        let targetsChildren = detectChildrenAudience(from: lower)
        let notes = extractDescription(from: message)

        let filename = generateFilename(company: operatorName ?? serviceName, service: serviceName, type: documentType)

        return KoreanPrivacyTermsRequest(
            serviceName: serviceName,
            operatorName: operatorName,
            contactEmail: contactEmail,
            serviceType: serviceType,
            documentType: documentType,
            collectsPersonalInfo: collectsPersonalInfo,
            usesAnalytics: usesAnalytics,
            usesAds: usesAds,
            usesPayments: usesPayments,
            handlesLocation: handlesLocation,
            targetsChildren: targetsChildren,
            notes: notes,
            filename: filename
        )
    }

    /// 더 필요한 정보가 있는지 확인한다.
    /// serviceName이 없거나 비어 있으면 true.
    static func needsMoreInfo(_ request: KoreanPrivacyTermsRequest?) -> Bool {
        guard let req = request else { return true }
        return req.serviceName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 타사 공식 문서로 보이는 요청인지 확인한다.
    /// 타사/기관으로 보이는 키워드가 있고 소유 문맥이 없으면 true.
    static func needsOwnershipConfirmation(for message: String) -> Bool {
        let lower = message.lowercased()

        // 타사/기관 키워드
        let corporateKeywords = [
            "공식", "삼성", "애플", "구글", "아마존", "마이크로소프트",
            "카카오", "네이버", "라인", "쿠팡", "당근", "배달의민족",
            "정부", "공공기관", "청청", "부청", "국가", "서울시", "경기도"
        ]

        // 소유 문맥 키워드
        let ownershipKeywords = [
            "내 앱", "내 서비스", "우리 서비스", "출시할", "만들고 있는",
            "운영하는", "만들 예정", "개발 중인", "직접 운영", "내가 만든"
        ]

        let hasCorporateKeyword = corporateKeywords.contains { lower.contains($0) }
        let hasOwnershipContext = ownershipKeywords.contains { lower.contains($0) }

        return hasCorporateKeyword && !hasOwnershipContext
    }

    // MARK: - Extraction helpers

    /// 서비스명을 추출한다 (필수).
    /// 기본값 없음 — 못 찾으면 nil.
    private static func extractServiceName(from message: String) -> String? {
        let serviceMarkers = ["서비스", "앱", "어플", "애플리케이션", "플랫폼", "사이트", "웹사이트", "프로그램"]

        for marker in serviceMarkers {
            if let range = message.range(of: marker) {
                let beforeMarker = message[..<range.lowerBound]
                let words = beforeMarker.split(separator: " ").map(String.init)
                let serviceName = words.suffix(2).joined(separator: " ")
                if !serviceName.isEmpty && serviceName.count > 1 {
                    return serviceName + marker
                }
            }
        }

        // 첫 단어가 서비스명일 수 있음
        let words = message.split(separator: " ").map(String.init)
        if let firstWord = words.first, firstWord.count > 1 && !firstWord.contains("개인정보") && !firstWord.contains("약관") {
            return firstWord
        }

        return nil
    }

    /// 운영자명(회사명)을 추출한다 (선택).
    private static func extractOperatorName(from message: String) -> String? {
        let markers = ["가", "은", "는", "에서", "의"]

        for marker in markers {
            if let range = message.range(of: marker) {
                let beforeMarker = message[..<range.lowerBound]
                let words = beforeMarker.split(separator: " ").map(String.init)
                if let lastWord = words.last, !lastWord.isEmpty && lastWord.count > 1 {
                    return lastWord
                }
            }
        }

        return nil
    }

    /// 연락처 이메일을 추출한다 (선택).
    private static func extractContactEmail(from message: String) -> String? {
        let emailPattern = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
        if let range = message.range(of: emailPattern, options: .regularExpression) {
            return String(message[range])
        }
        return nil
    }

    /// 서비스 유형을 추출한다 (선택).
    private static func extractServiceType(from message: String) -> String? {
        let lower = message.lowercased()
        let types = ["모바일앱", "웹사이트", "웹앱", "데스크톱앱", "게임", "소셜미디어"]

        for type in types {
            if lower.contains(type) {
                return type
            }
        }

        return nil
    }

    /// 개인정보 수집 여부를 감지한다.
    private static func detectPersonalInfoCollection(from lower: String) -> Bool {
        let keywords = ["회원가입", "이메일", "전화번호", "이름", "닉네임", "프로필", "사진", "업로드", "계정", "가입"]
        return keywords.contains { lower.contains($0) }
    }

    /// 분석 도구 사용 여부를 감지한다.
    private static func detectAnalytics(from lower: String) -> Bool {
        let keywords = ["분석", "firebase", "ga", "analytics", "로그분석", "데이터분석"]
        return keywords.contains { lower.contains($0) }
    }

    /// 광고 사용 여부를 감지한다.
    private static func detectAds(from lower: String) -> Bool {
        let keywords = ["광고", "애드몹", "admob", "배너", "수익화", "광고수익"]
        return keywords.contains { lower.contains($0) }
    }

    /// 결제 사용 여부를 감지한다.
    private static func detectPayments(from lower: String) -> Bool {
        let keywords = ["결제", "구독", "인앱결제", "유료", "환불", "결제처리"]
        return keywords.contains { lower.contains($0) }
    }

    /// 위치정보 사용 여부를 감지한다.
    private static func detectLocation(from lower: String) -> Bool {
        let keywords = ["위치", "gps", "지도", "주변", "위치정보"]
        return keywords.contains { lower.contains($0) }
    }

    /// 아동 대상 여부를 감지한다.
    private static func detectChildrenAudience(from lower: String) -> Bool {
        let keywords = ["아동", "만14세", "어린이", "키즈", "아이", "유아"]
        return keywords.contains { lower.contains($0) }
    }

    /// 설명(추가 정보)을 추출한다.
    private static func extractDescription(from message: String) -> String? {
        let lines = message.components(separatedBy: .newlines)
        if lines.count > 1 {
            let bodyLines = lines.dropFirst()
            let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty && body.count > 5 {
                return body
            }
        }
        return nil
    }

    /// 저장할 파일명을 생성한다.
    private static func generateFilename(company: String, service: String, type: KoreanPrivacyDocumentType) -> String {
        let year = Calendar.current.component(.year, from: Date())
        let typeStr = type == .privacy ? "개인정보처리방침" : (type == .terms ? "이용약관" : "약관")

        let cleanCompany = company.replacingOccurrences(of: " ", with: "_")
        let cleanService = service.replacingOccurrences(of: " ", with: "_")

        return "\(cleanCompany)_\(cleanService)_\(typeStr)_\(year).md"
    }

    // MARK: - Prompt generation

    /// privacy-terms 스킬을 위한 프롬프트를 빌드한다.
    /// 구조화된 플래그를 포함하여 LLM에 명확한 지침을 제공한다.
    static func buildPrompt(for request: KoreanPrivacyTermsRequest) -> String {
        let docTypeText = request.documentType == .privacy
            ? "개인정보처리방침"
            : (request.documentType == .terms ? "이용약관" : "개인정보처리방침 및 이용약관")

        let flagsSection = """
        === 서비스 정보 ===
        서비스명: \(request.serviceName)
        운영자: \(request.operatorName ?? "명시 예정")
        연락처: \(request.contactEmail ?? "명시 예정")
        유형: \(request.serviceType ?? "기타")

        === 기능별 사용 현황 ===
        개인정보 수집: \(request.collectsPersonalInfo ? "예" : "아니오")
        분석 도구: \(request.usesAnalytics ? "예 (예: Firebase)" : "아니오")
        광고 표시: \(request.usesAds ? "예 (예: AdMob)" : "아니오")
        결제 기능: \(request.usesPayments ? "예 (구독 또는 인앱결제)" : "아니오")
        위치정보: \(request.handlesLocation ? "예" : "아니오")
        아동 대상: \(request.targetsChildren ? "예 (만 14세 미만 포함)" : "아니오")
        """

        let basePrompt = """
        아래 정보를 바탕으로 한국 온라인 서비스용 \(docTypeText)을(를) 마크다운 형식으로 작성하세요.

        \(flagsSection)

        \(request.notes.map { "추가 정보: \($0)" } ?? "")

        생성 규칙:
        1. 마크다운 헤더(# ## ###)로 구조화하세요.
        2. 다음 섹션을 반드시 포함하세요:
           - 서비스 개요 (한두 문장)
           - 운영자 및 책임자
           - 개인정보 수집 항목 및 이용 목적
           - 개인정보 보관 기간
           - 개인정보 보호 조치
           - 사용자 권리
           - 제3자 공유 정책
           - 서비스 개선/분석 방침
           - 연락처 및 문의
           - 약관 변경 공지
        3. 명시된 기능(광고, 분석, 결제, 위치정보)에 해당하는 항목만 포함하세요.
        4. "운영자: 명시 예정" 같은 경우 TODO 마크로 표시하세요 (예: [TODO: 운영자 정보 입력])
        5. 한국어로 작성하고 일반인 이해 수준으로 설명하세요.

        ⚠️ 중요 주의 사항:
        - 이 문서는 출시 준비용 초안입니다.
        - 실제 배포 전에 전문가 검토가 필수입니다.
        - 법적 책임: 개인정보보호법 준수를 보장하지 않습니다.
        - SDK 버전, 광고 네트워크, 결제 제공자 등이 변경되면 업데이트하세요.
        """

        return basePrompt
    }

    /// 추출된 요청이 유효한지 검증한다.
    static func validate(_ request: KoreanPrivacyTermsRequest) -> Bool {
        return !request.serviceName.isEmpty &&
               !request.filename.isEmpty
    }
}
