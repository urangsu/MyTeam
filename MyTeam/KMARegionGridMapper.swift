import Foundation

struct KMAGridRegion: Sendable, Equatable {
    let name: String
    let nx: Int
    let ny: Int
    let aliases: [String]
}

enum KMARegionGridMapper {
    nonisolated static let defaultRegion = KMAGridRegion(name: "서울", nx: 60, ny: 127, aliases: ["서울"])

    nonisolated static let knownRegions: [KMAGridRegion] = [
        KMAGridRegion(name: "서울", nx: 60, ny: 127, aliases: ["서울특별시", "강남", "서초", "송파", "마포", "종로"]),
        KMAGridRegion(name: "부산", nx: 98, ny: 76, aliases: ["부산광역시", "해운대", "서면"]),
        KMAGridRegion(name: "대구", nx: 89, ny: 90, aliases: ["대구광역시"]),
        KMAGridRegion(name: "인천", nx: 55, ny: 124, aliases: ["인천광역시"]),
        KMAGridRegion(name: "광주", nx: 58, ny: 74, aliases: ["광주광역시"]),
        KMAGridRegion(name: "대전", nx: 67, ny: 100, aliases: ["대전광역시"]),
        KMAGridRegion(name: "울산", nx: 102, ny: 84, aliases: ["울산광역시"]),
        KMAGridRegion(name: "세종", nx: 66, ny: 103, aliases: ["세종특별자치시"]),
        KMAGridRegion(name: "수원", nx: 60, ny: 121, aliases: ["경기 수원", "수원시"]),
        KMAGridRegion(name: "성남", nx: 62, ny: 123, aliases: ["분당", "판교", "성남시"]),
        KMAGridRegion(name: "용인", nx: 64, ny: 119, aliases: ["용인시"]),
        KMAGridRegion(name: "고양", nx: 57, ny: 128, aliases: ["고양시", "일산"]),
        KMAGridRegion(name: "춘천", nx: 73, ny: 134, aliases: ["춘천시"]),
        KMAGridRegion(name: "강릉", nx: 92, ny: 131, aliases: ["강릉시"]),
        KMAGridRegion(name: "청주", nx: 69, ny: 107, aliases: ["청주시"]),
        KMAGridRegion(name: "천안", nx: 63, ny: 110, aliases: ["천안시"]),
        KMAGridRegion(name: "전주", nx: 63, ny: 89, aliases: ["전주시"]),
        KMAGridRegion(name: "군산", nx: 56, ny: 92, aliases: ["군산시"]),
        KMAGridRegion(name: "목포", nx: 50, ny: 67, aliases: ["목포시"]),
        KMAGridRegion(name: "여수", nx: 73, ny: 66, aliases: ["여수시"]),
        KMAGridRegion(name: "광양", nx: 73, ny: 70, aliases: ["광양시"]),
        KMAGridRegion(name: "순천", nx: 70, ny: 70, aliases: ["순천시"]),
        KMAGridRegion(name: "포항", nx: 102, ny: 94, aliases: ["포항시"]),
        KMAGridRegion(name: "창원", nx: 90, ny: 77, aliases: ["창원시", "마산", "진해"]),
        KMAGridRegion(name: "진주", nx: 81, ny: 75, aliases: ["진주시"]),
        KMAGridRegion(name: "제주", nx: 52, ny: 38, aliases: ["제주시", "제주도"]),
        KMAGridRegion(name: "서귀포", nx: 52, ny: 33, aliases: ["서귀포시"])
    ]

    nonisolated static func resolve(_ query: String?) -> KMAGridRegion? {
        let raw = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return defaultRegion }
        let normalized = normalize(raw)
        return knownRegions.first { region in
            raw.contains(region.name)
                || normalized.contains(region.name)
                || region.aliases.contains { alias in
                    raw.contains(alias) || normalized.contains(normalize(alias))
                }
        }
    }

    nonisolated static func userFacingUnsupportedMessage(for query: String?) -> String {
        let region = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if region.isEmpty {
            return "지역명을 입력하면 기상청 격자 좌표로 바꿔 조회합니다."
        }
        return "'\(region)' 지역의 기상청 격자 좌표가 아직 등록되지 않았습니다. 서울, 부산, 광양, 포항처럼 등록된 지역명으로 다시 조회해 주세요."
    }

    private nonisolated static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "특별시", with: "")
            .replacingOccurrences(of: "광역시", with: "")
            .replacingOccurrences(of: "특별자치시", with: "")
            .replacingOccurrences(of: "특별자치도", with: "")
            .replacingOccurrences(of: "시", with: "")
            .replacingOccurrences(of: "군", with: "")
            .replacingOccurrences(of: "구", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
