import Foundation
import ZIPFoundation

enum DARTCompanyResolutionSource: String, Sendable, Equatable {
    case directCorpCode
    case officialStockCodeIndex
    case officialCompanyNameIndex
    case ambiguous
    case notFound
}

struct DARTCompanyCandidate: Sendable, Equatable {
    let corpCode: String
    let corpName: String
    let stockCode: String?

    nonisolated var displayName: String {
        if let stockCode {
            return "\(corpName) (\(stockCode))"
        }
        return "\(corpName) (고유번호 \(corpCode))"
    }
}

struct DARTCompanyResolution: Sendable, Equatable {
    let input: String
    let corpCode: String?
    let corpName: String?
    let stockCode: String?
    let resolutionSource: DARTCompanyResolutionSource
    let candidates: [DARTCompanyCandidate]
    let indexUpdatedAt: Date?
    let isIndexStale: Bool

    nonisolated var isResolved: Bool {
        corpCode != nil
    }

    nonisolated var displayName: String {
        if let corpName, let stockCode {
            return "\(corpName) \(stockCode)"
        }
        if let corpName {
            return corpName
        }
        if let corpCode {
            return corpCode
        }
        return input
    }
}

nonisolated struct DARTCompanyIndexEntry: Codable, Sendable, Equatable {
    let corpCode: String
    let corpName: String
    let stockCode: String?
    let modifyDate: String?

    nonisolated var isListed: Bool {
        stockCode != nil
    }
}

struct DARTCompanyIndex: Sendable {
    let entries: [DARTCompanyIndexEntry]

    private let byCorpCode: [String: DARTCompanyIndexEntry]
    private let byStockCode: [String: [DARTCompanyIndexEntry]]
    private let byNormalizedName: [String: [DARTCompanyIndexEntry]]
    private let corpCodesByNameGram: [String: Set<String>]

    nonisolated init(entries: [DARTCompanyIndexEntry]) {
        self.entries = entries
        self.byCorpCode = Dictionary(entries.map { ($0.corpCode, $0) }, uniquingKeysWith: { first, _ in first })
        self.byStockCode = Dictionary(grouping: entries.compactMap { entry in
            entry.stockCode.map { ($0, entry) }
        }, by: { $0.0 }).mapValues { $0.map(\.1) }
        self.byNormalizedName = Dictionary(grouping: entries, by: { DARTCompanyResolver.normalizedName($0.corpName) })
        var gramIndex: [String: Set<String>] = [:]
        for entry in entries {
            let normalized = DARTCompanyResolver.normalizedName(entry.corpName)
            for gram in Set(DARTCompanyResolver.nameGrams(normalized)) {
                gramIndex[gram, default: []].insert(entry.corpCode)
            }
        }
        self.corpCodesByNameGram = gramIndex
    }

    nonisolated func resolve(
        input: String,
        indexUpdatedAt: Date?,
        isIndexStale: Bool
    ) -> DARTCompanyResolution {
        let trimmed = DARTCompanyResolver.cleanedInput(input)
        guard !trimmed.isEmpty else {
            return unresolved(input: input, candidates: [], updatedAt: indexUpdatedAt, isStale: isIndexStale)
        }

        if DARTCompanyResolver.isEightDigitCorpCode(trimmed) {
            if let entry = byCorpCode[trimmed] {
                return resolved(
                    entry: entry,
                    input: input,
                    source: .directCorpCode,
                    updatedAt: indexUpdatedAt,
                    isStale: isIndexStale
                )
            }
            return DARTCompanyResolution(
                input: input,
                corpCode: trimmed,
                corpName: nil,
                stockCode: nil,
                resolutionSource: .directCorpCode,
                candidates: [],
                indexUpdatedAt: indexUpdatedAt,
                isIndexStale: isIndexStale
            )
        }

        if DARTCompanyResolver.isSixDigitStockCode(trimmed) {
            return resolution(
                matches: byStockCode[trimmed] ?? [],
                input: input,
                source: .officialStockCodeIndex,
                updatedAt: indexUpdatedAt,
                isStale: isIndexStale
            )
        }

        let normalized = DARTCompanyResolver.normalizedName(trimmed)
        let exactMatches = byNormalizedName[normalized] ?? []
        if !exactMatches.isEmpty {
            return resolution(
                matches: exactMatches,
                input: input,
                source: .officialCompanyNameIndex,
                updatedAt: indexUpdatedAt,
                isStale: isIndexStale
            )
        }

        let grams = DARTCompanyResolver.nameGrams(normalized)
        let candidateCorpCodes = grams
            .compactMap { corpCodesByNameGram[$0] }
            .reduce(nil as Set<String>?) { partial, codes in
                partial.map { $0.intersection(codes) } ?? codes
            } ?? []
        let suggestions = candidateCorpCodes
            .compactMap { byCorpCode[$0] }
            .filter { DARTCompanyResolver.normalizedName($0.corpName).contains(normalized) }
            .sorted { lhs, rhs in
                if lhs.isListed != rhs.isListed { return lhs.isListed }
                return lhs.corpName.localizedStandardCompare(rhs.corpName) == .orderedAscending
            }
            .prefix(5)
            .map(candidate)

        return unresolved(
            input: input,
            candidates: Array(suggestions),
            updatedAt: indexUpdatedAt,
            isStale: isIndexStale
        )
    }

    nonisolated private func resolution(
        matches: [DARTCompanyIndexEntry],
        input: String,
        source: DARTCompanyResolutionSource,
        updatedAt: Date?,
        isStale: Bool
    ) -> DARTCompanyResolution {
        guard matches.count == 1, let entry = matches.first else {
            return unresolved(
                input: input,
                candidates: matches.prefix(5).map(candidate),
                updatedAt: updatedAt,
                isStale: isStale,
                source: matches.isEmpty ? .notFound : .ambiguous
            )
        }
        return resolved(entry: entry, input: input, source: source, updatedAt: updatedAt, isStale: isStale)
    }

    nonisolated private func resolved(
        entry: DARTCompanyIndexEntry,
        input: String,
        source: DARTCompanyResolutionSource,
        updatedAt: Date?,
        isStale: Bool
    ) -> DARTCompanyResolution {
        DARTCompanyResolution(
            input: input,
            corpCode: entry.corpCode,
            corpName: entry.corpName,
            stockCode: entry.stockCode,
            resolutionSource: source,
            candidates: [],
            indexUpdatedAt: updatedAt,
            isIndexStale: isStale
        )
    }

    nonisolated private func unresolved(
        input: String,
        candidates: [DARTCompanyCandidate],
        updatedAt: Date?,
        isStale: Bool,
        source: DARTCompanyResolutionSource? = nil
    ) -> DARTCompanyResolution {
        DARTCompanyResolution(
            input: input,
            corpCode: nil,
            corpName: nil,
            stockCode: nil,
            resolutionSource: source ?? (candidates.isEmpty ? .notFound : .ambiguous),
            candidates: candidates,
            indexUpdatedAt: updatedAt,
            isIndexStale: isStale
        )
    }

    nonisolated private func candidate(_ entry: DARTCompanyIndexEntry) -> DARTCompanyCandidate {
        DARTCompanyCandidate(
            corpCode: entry.corpCode,
            corpName: entry.corpName,
            stockCode: entry.stockCode
        )
    }
}

enum DARTCompanyIndexError: LocalizedError, Sendable {
    case invalidDownload
    case missingCompanyXML
    case invalidCompanyXML
    case emptyCompanyIndex

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidDownload:
            return "OpenDART 회사 목록을 내려받지 못했습니다."
        case .missingCompanyXML:
            return "OpenDART 회사 목록 압축 파일에 CORPCODE.xml이 없습니다."
        case .invalidCompanyXML:
            return "OpenDART 회사 목록을 해석하지 못했습니다."
        case .emptyCompanyIndex:
            return "OpenDART 회사 목록이 비어 있습니다."
        }
    }
}

nonisolated private struct DARTCompanyIndexSnapshot: Codable, Sendable {
    let downloadedAt: Date
    let entries: [DARTCompanyIndexEntry]
}

actor DARTCompanyIndexStore {
    static let shared = DARTCompanyIndexStore()

    private static let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60
    private let cacheURL: URL
    private var memorySnapshot: DARTCompanyIndexSnapshot?
    private var refreshTask: Task<DARTCompanyIndexSnapshot, Error>?

    init(cacheURL: URL = AppPaths.cacheDirectory
        .appendingPathComponent("DART", isDirectory: true)
        .appendingPathComponent("company-index.json")) {
        self.cacheURL = cacheURL
    }

    func resolve(input: String, apiKey: String, now: Date = Date()) async throws -> DARTCompanyResolution {
        let trimmed = DARTCompanyResolver.cleanedInput(input)
        if DARTCompanyResolver.isEightDigitCorpCode(trimmed) {
            return DARTCompanyIndex(entries: []).resolve(
                input: input,
                indexUpdatedAt: memorySnapshot?.downloadedAt,
                isIndexStale: false
            )
        }

        if let snapshot = loadCachedSnapshot() {
            let isStale = now.timeIntervalSince(snapshot.downloadedAt) > Self.maxCacheAge
            if isStale {
                refreshInBackground(apiKey: apiKey)
            }
            return DARTCompanyIndex(entries: snapshot.entries).resolve(
                input: input,
                indexUpdatedAt: snapshot.downloadedAt,
                isIndexStale: isStale
            )
        }

        let snapshot = try await refresh(apiKey: apiKey)
        return DARTCompanyIndex(entries: snapshot.entries).resolve(
            input: input,
            indexUpdatedAt: snapshot.downloadedAt,
            isIndexStale: false
        )
    }

    private func loadCachedSnapshot() -> DARTCompanyIndexSnapshot? {
        if let memorySnapshot {
            return memorySnapshot
        }
        guard let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(DARTCompanyIndexSnapshot.self, from: data),
              !snapshot.entries.isEmpty else {
            return nil
        }
        memorySnapshot = snapshot
        return snapshot
    }

    private func refreshInBackground(apiKey: String) {
        guard refreshTask == nil else { return }
        let task = makeRefreshTask(apiKey: apiKey)
        refreshTask = task
        Task {
            do {
                _ = try await finishRefresh(task)
            } catch {
                AppLog.warning("[DARTCompanyIndex] background refresh failed: \(error.localizedDescription)")
            }
        }
    }

    private func refresh(apiKey: String) async throws -> DARTCompanyIndexSnapshot {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = makeRefreshTask(apiKey: apiKey)
        refreshTask = task
        return try await finishRefresh(task)
    }

    private func makeRefreshTask(apiKey: String) -> Task<DARTCompanyIndexSnapshot, Error> {
        Task.detached(priority: .utility) {
            try await Self.downloadSnapshot(apiKey: apiKey)
        }
    }

    private func finishRefresh(_ task: Task<DARTCompanyIndexSnapshot, Error>) async throws -> DARTCompanyIndexSnapshot {
        do {
            let snapshot = try await task.value
            try persist(snapshot)
            memorySnapshot = snapshot
            refreshTask = nil
            AppLog.info("[DARTCompanyIndex] official index saved: \(snapshot.entries.count)")
            return snapshot
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func persist(_ snapshot: DARTCompanyIndexSnapshot) throws {
        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: cacheURL, options: .atomic)
    }

    nonisolated private static func downloadSnapshot(apiKey: String) async throws -> DARTCompanyIndexSnapshot {
        var components = URLComponents(string: "https://opendart.fss.or.kr/api/corpCode.xml")
        components?.queryItems = [URLQueryItem(name: "crtfc_key", value: apiKey)]
        guard let url = components?.url else {
            throw DARTCompanyIndexError.invalidDownload
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              data.starts(with: [0x50, 0x4B]) else {
            throw DARTCompanyIndexError.invalidDownload
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("myteam-dart-corpcode-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try data.write(to: temporaryURL, options: .atomic)

        let archive = try Archive(url: temporaryURL, accessMode: .read)
        guard let entry = archive.first(where: { $0.path.uppercased().hasSuffix("CORPCODE.XML") }) else {
            throw DARTCompanyIndexError.missingCompanyXML
        }
        var xmlData = Data()
        _ = try archive.extract(entry) { xmlData.append($0) }

        let parser = DARTCorpCodeXMLParser()
        let entries = try parser.parse(data: xmlData)
        guard !entries.isEmpty else {
            throw DARTCompanyIndexError.emptyCompanyIndex
        }
        return DARTCompanyIndexSnapshot(downloadedAt: Date(), entries: entries)
    }
}

enum DARTCompanyResolver {
    static func resolve(input: String, apiKey: String) async throws -> DARTCompanyResolution {
        try await DARTCompanyIndexStore.shared.resolve(input: input, apiKey: apiKey)
    }

    nonisolated static func cleanedInput(_ input: String) -> String {
        input
            .replacingOccurrences(of: "corpCode:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "corp_code:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func isEightDigitCorpCode(_ input: String) -> Bool {
        input.range(of: #"^\d{8}$"#, options: .regularExpression) != nil
    }

    nonisolated static func isSixDigitStockCode(_ input: String) -> Bool {
        input.range(of: #"^\d{6}$"#, options: .regularExpression) != nil
    }

    nonisolated static func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "(주)", with: "")
            .replacingOccurrences(of: "주식회사", with: "")
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .joined()
            .trimmingCharacters(in: .punctuationCharacters)
    }

    nonisolated static func nameGrams(_ value: String) -> [String] {
        let characters = Array(value)
        guard characters.count >= 2 else { return [] }
        return (0..<(characters.count - 1)).map { index in
            String(characters[index...(index + 1)])
        }
    }
}

nonisolated private final class DARTCorpCodeXMLParser: NSObject, XMLParserDelegate {
    private var entries: [DARTCompanyIndexEntry] = []
    private var currentElement = ""
    private var currentText = ""
    private var fields: [String: String] = [:]

    func parse(data: Data) throws -> [DARTCompanyIndexEntry] {
        entries.removeAll(keepingCapacity: true)
        fields.removeAll(keepingCapacity: true)
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw DARTCompanyIndexError.invalidCompanyXML
        }
        return entries
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        if elementName == "list" {
            fields.removeAll(keepingCapacity: true)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["corp_code", "corp_name", "stock_code", "modify_date"].contains(elementName) {
            fields[elementName] = value
        } else if elementName == "list",
                  let corpCode = fields["corp_code"], corpCode.count == 8,
                  let corpName = fields["corp_name"], !corpName.isEmpty {
            let stockCode = fields["stock_code"].flatMap { $0.isEmpty ? nil : $0 }
            let modifyDate = fields["modify_date"].flatMap { $0.isEmpty ? nil : $0 }
            entries.append(DARTCompanyIndexEntry(
                corpCode: corpCode,
                corpName: corpName,
                stockCode: stockCode,
                modifyDate: modifyDate
            ))
        }
        currentElement = ""
        currentText = ""
    }
}
