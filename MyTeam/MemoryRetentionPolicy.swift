import CryptoKit
import Foundation

struct MemoryRetentionPolicy: Codable, Equatable, Sendable {
    let sensitivity: MemorySensitivity
    let approvedAt: Date?
    let expiresAt: Date?
    let canPersistInUserDefaults: Bool
    let requiresExplicitApproval: Bool
}

struct StoredAutomationTask: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let sanitizedPrompt: String
    let scheduleSummary: String
    let sensitivity: MemorySensitivity
    let createdAt: Date
    let expiresAt: Date?
}

enum MemoryWriteGuard {
    static func evaluateFact(_ text: String) -> MemoryRetentionPolicy {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        if containsSensitivePayload(lowered) {
            return MemoryRetentionPolicy(
                sensitivity: .secret,
                approvedAt: nil,
                expiresAt: nil,
                canPersistInUserDefaults: false,
                requiresExplicitApproval: false
            )
        }

        if containsPersonalPayload(lowered) {
            return MemoryRetentionPolicy(
                sensitivity: .personal,
                approvedAt: nil,
                expiresAt: nil,
                canPersistInUserDefaults: false,
                requiresExplicitApproval: true
            )
        }

        if containsWorkspacePayload(lowered) {
            return MemoryRetentionPolicy(
                sensitivity: .workspace,
                approvedAt: Date(),
                expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 180),
                canPersistInUserDefaults: true,
                requiresExplicitApproval: false
            )
        }

        return MemoryRetentionPolicy(
            sensitivity: .publicLow,
            approvedAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 365),
            canPersistInUserDefaults: true,
            requiresExplicitApproval: false
        )
    }

    static func redactedPreview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lowered = trimmed.lowercased()
        if containsSensitivePayload(lowered) || trimmed.count > 160 {
            let hash = sha256Hex(of: trimmed)
            return "[len=\(trimmed.count) hash=\(String(hash.prefix(12)))]"
        }

        if containsPersonalPayload(lowered) {
            return trimmed.replacingOccurrences(
                of: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
                with: "[redacted-email]",
                options: .regularExpression
            )
        }

        return trimmed
    }

    private static func containsSensitivePayload(_ lowered: String) -> Bool {
        let patterns = ["token", "key", "secret", "password", "auth", "apikey", "api key", "access token", "refresh token"]
        return patterns.contains(where: { lowered.contains($0) })
    }

    private static func containsPersonalPayload(_ lowered: String) -> Bool {
        let patterns = ["email", "mail body", "본문", "body", "sourceText", "source text", "content", "message to save"]
        return patterns.contains(where: { lowered.contains($0) })
    }

    private static func containsWorkspacePayload(_ lowered: String) -> Bool {
        let patterns = ["workspace", "project", "preference", "선호", "항상", "좋아", "싫어", "remember", "기억"]
        return patterns.contains(where: { lowered.contains($0) })
    }

    private static func sha256Hex(of text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
