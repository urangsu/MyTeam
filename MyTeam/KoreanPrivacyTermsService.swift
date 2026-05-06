import Foundation

// MARK: - DocumentType
enum KoreanPrivacyDocumentType: String {
    case privacy = "privacy"
    case terms = "terms"
    case both = "both"
}

// MARK: - KoreanPrivacyTermsRequest
struct KoreanPrivacyTermsRequest {
    let companyName: String
    let serviceName: String
    let description: String
    let documentType: KoreanPrivacyDocumentType  // privacy | terms | both
    let filename: String
}

// MARK: - KoreanPrivacyTermsService
enum KoreanPrivacyTermsService {

    /// 사용자 메시지에서 회사명, 서비스명, 설명을 추출한다.
    /// 반환하는 요청은 workflow에서 LLM 호출 시 사용된다.
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

        // 회사명/서비스명 추출 (간단한 휴리스틱)
        let companyName = extractCompanyName(from: message) ?? "회사"
        let serviceName = extractServiceName(from: message) ?? "서비스"
        let description = extractDescription(from: message) ?? ""

        let filename = generateFilename(company: companyName, service: serviceName, type: documentType)

        return KoreanPrivacyTermsRequest(
            companyName: companyName,
            serviceName: serviceName,
            description: description,
            documentType: documentType,
            filename: filename
        )
    }

    /// 회사명을 추출한다.
    /// 예: "삼성전자에서 갤럭시 폰을 위한..."에서 "삼성전자" 추출
    private static func extractCompanyName(from message: String) -> String? {
        // 콜론이나 "를 위한", "의" 등의 마커 앞의 첫 단어를 추출
        let markers = ["를 위한", "의", "에서", ":"]

        for marker in markers {
            if let range = message.range(of: marker) {
                let beforeMarker = message[..<range.lowerBound]
                let words = beforeMarker.split(separator: " ").map(String.init)
                if let lastWord = words.last, !lastWord.isEmpty {
                    return lastWord
                }
            }
        }

        // 마커 없으면 첫 단어 추출
        let words = message.split(separator: " ").map(String.init)
        if let firstWord = words.first, !firstWord.isEmpty && firstWord.count > 1 {
            return firstWord
        }

        return nil
    }

    /// 서비스명을 추출한다.
    /// 예: "... 갤럭시 폰 ... 약관"에서 "갤럭시 폰" 추출
    private static func extractServiceName(from message: String) -> String? {
        // "서비스", "앱", "어플", "플랫폼", "사이트" 등 앞의 명사들 추출
        let serviceMarkers = ["서비스", "앱", "어플", "애플리케이션", "플랫폼", "사이트", "웹사이트", "애플리케이션", "프로그램"]

        for marker in serviceMarkers {
            if let range = message.range(of: marker) {
                // marker 앞의 1-2개 단어 추출
                let beforeMarker = message[..<range.lowerBound]
                let words = beforeMarker.split(separator: " ").map(String.init)
                let serviceName = words.suffix(2).joined(separator: " ")
                if !serviceName.isEmpty {
                    return serviceName + marker
                }
            }
        }

        return nil
    }

    /// 설명 (추가 조건)을 추출한다.
    /// 예: "이 서비스는 B2C 마켓플레이스입니다"에서 추출
    private static func extractDescription(from message: String) -> String? {
        let lines = message.components(separatedBy: .newlines)

        // 여러 줄이면 두 번째 줄 이후를 설명으로 취급
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
    /// 예: "삼성전자_갤럭시_개인정보처리방침_2026.md"
    private static func generateFilename(company: String, service: String, type: KoreanPrivacyDocumentType) -> String {
        let year = Calendar.current.component(.year, from: Date())
        let typeStr = type == .privacy ? "개인정보처리방침" : (type == .terms ? "이용약관" : "약관")

        // 파일명에서 특수문자 제거
        let cleanCompany = company.replacingOccurrences(of: " ", with: "_")
        let cleanService = service.replacingOccurrences(of: " ", with: "_")

        return "\(cleanCompany)_\(cleanService)_\(typeStr)_\(year).md"
    }

    /// privacy-terms 스킬을 위한 프롬프트를 빌드한다.
    /// LLM 호출 시 이 프롬프트를 사용한다.
    static func buildPrompt(for request: KoreanPrivacyTermsRequest) -> String {
        let docTypeText = request.documentType == .privacy
            ? "개인정보처리방침"
            : (request.documentType == .terms ? "이용약관" : "개인정보처리방침 및 이용약관")

        let basePrompt = """
        다음 정보를 바탕으로 한국 온라인 서비스용 \(docTypeText)을(를) 마크다운 형식으로 작성하세요.

        회사명: \(request.companyName)
        서비스명: \(request.serviceName)
        \(request.description.isEmpty ? "" : "설명: \(request.description)")

        생성 규칙:
        1. 마크다운 헤더 (# ## ###)로 구조화하세요.
        2. 다음을 반드시 포함하세요:
           - 서비스 개요 (한두 문장)
           - 목적 및 범위
           - 주요 조항 (개인정보 수집 항목, 이용 목적, 보관 기간, 보안, 권리, 변경 예고 등)
           - 연락처 정보 (실제 연락처가 없으면 "고객 지원" 섹션으로 예시)
        3. 마크다운 리스트, 테이블 등을 활용하여 명확하게 표시하세요.
        4. 한국어로 작성하고, 법적 용어는 일반인이 이해하기 쉽도록 설명하세요.

        법적 책임 조항:
        이 문서는 AI가 생성한 샘플 문서이며, 법적 조언이 아닙니다.
        실제 서비스 배포 전에 법무팀 또는 전문 변호사의 검토를 받으세요.
        규제 기관 가이드, 업계 표준, 기업 정책에 맞게 조정이 필요합니다.
        """

        return basePrompt
    }

    /// 추출된 요청이 유효한지 검증한다.
    static func validate(_ request: KoreanPrivacyTermsRequest) -> Bool {
        return !request.companyName.isEmpty &&
               !request.serviceName.isEmpty &&
               !request.filename.isEmpty
    }
}
