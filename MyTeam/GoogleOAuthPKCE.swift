import Foundation
import CryptoKit
import Security

struct GoogleOAuthPKCE: Equatable {
    let codeVerifier: String
    let codeChallenge: String
    let method: String
}

enum GoogleOAuthPKCEGenerator {
    static func generate() throws -> GoogleOAuthPKCE {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw GoogleOAuthPKCEError.randomGenerationFailed
        }

        let verifier = Data(bytes).base64URLEncodedString()
        let challengeData = Data(SHA256.hash(data: Data(verifier.utf8)))
        let challenge = challengeData.base64URLEncodedString()
        return GoogleOAuthPKCE(codeVerifier: verifier, codeChallenge: challenge, method: "S256")
    }
}

enum GoogleOAuthPKCEError: Error {
    case randomGenerationFailed
}

private extension Data {
    func base64URLEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
