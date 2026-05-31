import Foundation

// MARK: - DemoMode

/// App Store 심사자 및 신규 사용자를 위한 데모 모드.
/// API 키 없이도 앱의 핵심 기능을 이해할 수 있는 샘플 데이터를 제공합니다.
/// 샘플 데이터는 명확히 "예시"로 표시하여 실제 조회 결과와 혼동하지 않도록 합니다.
enum DemoMode {
    /// 데모 모드 활성화 여부
    static var isEnabled: Bool {
        // 향후: 사용자 설정 또는 App Store 심사 환경 감지로 활성화
        // 현재는 API 키가 없는 경우에만 샘플 데이터 힌트를 표시
        let hasAnyKey = ExternalProvider.allCases.contains { provider in
            SecureCredentialStore.shared.hasKey(for: provider)
        }
        return !hasAnyKey
    }

    /// 데모 모드임을 나타내는 표시 문구
    static let sampleLabel = "예시"
    static let sampleBadgeText = "예시 데이터"
    static let sampleDisclaimer = "이것은 예시 데이터입니다. 실제 정보를 보려면 서비스를 연결해 주세요."
}

// MARK: - DemoRoomSeeder (Stub)

/// 데모용 초기 방/대화 데이터를 생성합니다.
/// 실제 구현은 다음 라운드에서 진행합니다.
struct DemoRoomSeeder {
    /// 데모 방 생성 (다음 라운드 구현 예정)
    static func seedIfNeeded() {
        // TODO: 첫 실행 시 샘플 대화/아티팩트 생성
        // - 샘플 메일 요약
        // - 샘플 PDF 요약
        // - 샘플 날씨 카드 (예시 표시)
        // - 샘플 공시 카드 (예시 표시)
    }
}

// MARK: - SampleArtifactSeeder (Stub)

/// 샘플 아티팩트 데이터 정의.
struct SampleArtifactSeeder {
    struct SampleEntry {
        let title: String
        let content: String
        let isDemoOnly: Bool
    }

    static let samples: [SampleEntry] = [
        SampleEntry(
            title: "[예시] 주간 업무 보고서",
            content: "이것은 예시 보고서입니다. 실제 AI와 대화하면 맞춤 보고서를 만들 수 있어요.",
            isDemoOnly: true
        ),
        SampleEntry(
            title: "[예시] 오늘 날씨 요약",
            content: "이것은 예시 날씨 카드입니다. 기상청 API를 연결하면 실제 날씨를 확인할 수 있어요.",
            isDemoOnly: true
        )
    ]
}
