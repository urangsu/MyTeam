import Foundation

// MARK: - SkillStoreError

enum SkillStoreError: Error, LocalizedError {
    case notFound(String)
    case alreadyInstalled(String)
    case invalidManifest(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):           return "스킬 '\(id)'을 찾을 수 없습니다."
        case .alreadyInstalled(let id):   return "스킬 '\(id)'은 이미 설치되어 있습니다."
        case .invalidManifest(let reason): return "스킬 매니페스트 오류: \(reason)"
        }
    }
}

// MARK: - UserSkillStore

actor UserSkillStore {
    static let shared = UserSkillStore()
    private init() {}

    // MARK: - Directory

    /// ~/Library/Application Support/MyTeam/UserSkills/
    nonisolated static var skillsDirectory: URL {
        AppPaths.applicationSupportDirectory
            .appendingPathComponent("UserSkills", isDirectory: true)
    }

    // MARK: - UserSkillRecord

    struct UserSkillRecord: Codable, Identifiable {
        let id: String           // SkillManifest.id 와 동일
        let installedAt: Date
        var isEnabled: Bool      // 설치 시 항상 false
        let manifest: SkillManifest
        var warningFlags: [String]
    }

    // MARK: - Dangerous Permissions (설치 시 경고 플래그 기록)

    private let dangerousPermissions: Set<SkillPermission> = [
        .browserAutomation,
        .officeLive,
        .requiresUserLogin,
        .readsPersonalData,
        .sendsMessage,
        .makesReservation,
        .handlesPayment,
        .financialData
    ]

    // MARK: - Read

    func installedSkills() async -> [UserSkillRecord] {
        let dir = Self.skillsDirectory
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasSuffix(".skill.json") }
            .compactMap { url -> UserSkillRecord? in
                guard let data = try? Data(contentsOf: url),
                      let record = try? JSONDecoder().decode(UserSkillRecord.self, from: data)
                else {
                    AppLog.warning("[UserSkillStore] 파싱 실패: \(url.lastPathComponent)")
                    return nil
                }
                return record
            }
            .sorted { $0.installedAt < $1.installedAt }
    }

    // MARK: - Install

    func installUserSkill(manifest: SkillManifest) async throws {
        // 1. 기본 검증 (UserSkillStore 독립 — SkillRegistry 호출 없음)
        guard !manifest.id.isEmpty, !manifest.name.isEmpty else {
            throw SkillStoreError.invalidManifest("id 또는 name이 비어 있습니다.")
        }
        guard !manifest.triggers.isEmpty else {
            throw SkillStoreError.invalidManifest("triggers가 비어 있습니다.")
        }
        guard !manifest.allowedScopes.isEmpty else {
            throw SkillStoreError.invalidManifest("allowedScopes가 비어 있습니다.")
        }

        // 2. 중복 설치 확인
        let fileURL = Self.skillsDirectory.appendingPathComponent("\(manifest.id).skill.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            throw SkillStoreError.alreadyInstalled(manifest.id)
        }

        // 3. Dangerous permission 경고 수집
        let warnings = manifest.requiredPermissions
            .filter { dangerousPermissions.contains($0) }
            .map { "위험 권한 포함: \($0.rawValue)" }

        if !warnings.isEmpty {
            AppLog.warning("[UserSkillStore] '\(manifest.id)' 위험 권한 \(warnings.count)개: \(warnings.joined(separator: ", "))")
        }

        // 4. Directory 생성 (lazy)
        let dir = Self.skillsDirectory
        try FileManager.default.createDirectory(at: dir,
            withIntermediateDirectories: true, attributes: nil)

        // 5. 항상 isEnabled=false로 저장
        let record = UserSkillRecord(
            id: manifest.id,
            installedAt: Date(),
            isEnabled: false,
            manifest: manifest,
            warningFlags: warnings
        )

        let data = try JSONEncoder().encode(record)
        try data.write(to: fileURL, options: .atomic)

        AppLog.info("[UserSkillStore] 설치 완료: '\(manifest.id)' warnings=\(warnings.count) (기본 비활성)")
    }

    // MARK: - Uninstall

    func uninstallUserSkill(id: String) async throws {
        let fileURL = Self.skillsDirectory.appendingPathComponent("\(id).skill.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SkillStoreError.notFound(id)
        }
        try FileManager.default.removeItem(at: fileURL)
        AppLog.info("[UserSkillStore] 삭제 완료: '\(id)'")
    }
}
