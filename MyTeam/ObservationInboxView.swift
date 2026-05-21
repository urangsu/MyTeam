import SwiftUI

// MARK: - ObservationInboxView
// Round 247A-OBSERVE: pending observation을 현재 방 사용자에게 보여주는 inbox.
//
// 정책:
// - roomID == nil (pendingRoomSelection) observation만 표시
// - 이미 다른 roomID가 배정된 observation은 표시 금지
// - full path 표시 금지
// - 파일 내용 자동 분석 금지
// - "이 방에서 분석" → onAnalyze callback (attach만, 분석은 사용자 다음 action)
// - "무시" → onIgnore callback

struct ObservationInboxView: View {
    let roomID: UUID
    @ObservedObject var observationService: LocalObservationService
    let onAnalyze: (LocalObservation) -> Void
    let onIgnore: (LocalObservation) -> Void

    private var pendingForRoom: [LocalObservation] {
        // roomID nil인 observation만 — 이미 다른 방에 배정된 것은 표시 금지
        observationService.pendingObservations.filter { $0.roomID == nil && $0.isPending }
    }

    var body: some View {
        if !pendingForRoom.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("새로 발견한 자료")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(pendingForRoom.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                ForEach(pendingForRoom) { observation in
                    FileIntakeEventCardView(
                        observation: observation,
                        onAttach: { _ in onAnalyze(observation) },
                        onIgnore: { _ in onIgnore(observation) }
                    )
                    .padding(.horizontal, 8)
                }
            }
            .padding(.bottom, 8)
            .background(Color.orange.opacity(0.04))
            .overlay(
                Rectangle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(height: 1),
                alignment: .bottom
            )
        }
    }
}
