import Foundation

enum ResultRecoveryPolicy {
    static func shouldRetryUniversalDocument(
        verification: ResultVerificationSummary,
        attempt: Int
    ) -> Bool {
        attempt == 1 && verification.hasError
    }

    static func failureMessage() -> String {
        "결과물에 문제가 있어 저장하지 않았습니다. 조금 더 구체적인 원문이나 주제를 주시면 다시 만들 수 있습니다."
    }
}
