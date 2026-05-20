import Foundation
import Combine

// MARK: - LocalObservationService
// Round 243A-OBSERVE: room-scoped 관찰 이벤트 저장소.
//
// 정책:
// - roomID 있는 observation은 해당 방에만 보임
// - roomID 없는 observation은 pendingObservations (어느 방에 붙일지 사용자 결정)
// - 다른 방으로 자동 공유 금지
// - observation이 artifact가 되는 것은 분석 + 사용자 확인 후

@MainActor
final class LocalObservationService: ObservableObject {

    static let shared = LocalObservationService()
    private init() {}

    // MARK: - Storage

    /// 방별 확인된 observation
    @Published private(set) var observationsByRoom: [UUID: [LocalObservation]] = [:]

    /// roomID 미배정 — 사용자가 어느 방에 붙일지 결정 대기
    @Published private(set) var pendingObservations: [LocalObservation] = []

    // MARK: - Add / Detect

    /// 새 observation 추가. roomID가 있으면 해당 방에, 없으면 pending에.
    func addDetectedObservation(_ observation: LocalObservation) {
        if let roomID = observation.roomID {
            var list = observationsByRoom[roomID] ?? []
            list.removeAll { $0.id == observation.id }
            list.append(observation)
            observationsByRoom[roomID] = list
        } else {
            pendingObservations.removeAll { $0.id == observation.id }
            pendingObservations.append(observation)
        }
    }

    /// 편의: source + fileURL로 바로 추가
    func detect(
        source: ObservationSource,
        fileURL: URL?,
        displayName: String,
        contentKind: ObservationContentKind,
        fileSizeBytes: Int64? = nil,
        roomID: UUID? = nil
    ) {
        let obs = LocalObservation(
            roomID: roomID,
            source: source,
            fileURL: fileURL,
            displayName: displayName,
            contentKind: contentKind,
            fileSizeBytes: fileSizeBytes
        )
        addDetectedObservation(obs)
        AppLog.info("[ObservationService] detected: \(displayName) source=\(source.rawValue) room=\(roomID?.uuidString.prefix(8) ?? "pending")")
    }

    // MARK: - Room Attachment

    /// pending observation을 특정 방에 배정
    func attachObservation(_ id: UUID, to roomID: UUID) {
        guard let idx = pendingObservations.firstIndex(where: { $0.id == id }) else { return }
        var obs = pendingObservations.remove(at: idx)
        obs.roomID = roomID
        obs.status = .userConfirmed
        var list = observationsByRoom[roomID] ?? []
        list.append(obs)
        observationsByRoom[roomID] = list
        AppLog.info("[ObservationService] attached \(obs.displayName) → room \(roomID.uuidString.prefix(8))")
    }

    /// 방 안의 기존 observation 상태 업데이트
    func updateObservationStatus(_ id: UUID, in roomID: UUID, status: ObservationStatus) {
        guard var list = observationsByRoom[roomID],
              let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].status = status
        observationsByRoom[roomID] = list
    }

    // MARK: - Ignore

    /// pending observation 무시
    func ignorePendingObservation(_ id: UUID) {
        if let idx = pendingObservations.firstIndex(where: { $0.id == id }) {
            pendingObservations[idx].status = .ignored
            // 무시된 것은 pending 목록에서 제거
            pendingObservations.remove(at: idx)
        }
    }

    /// 방 observation 무시
    func ignoreObservation(_ id: UUID, in roomID: UUID) {
        updateObservationStatus(id, in: roomID, status: .ignored)
    }

    // MARK: - Query

    /// 방별 observation (terminal 상태 제외 가능)
    func observations(for roomID: UUID, includeTerminal: Bool = false) -> [LocalObservation] {
        let all = observationsByRoom[roomID] ?? []
        if includeTerminal { return all }
        return all.filter { !$0.status.isTerminal }
    }

    /// 아직 방에 배정되지 않은 observation
    func pendingRoomSelectionObservations() -> [LocalObservation] {
        pendingObservations.filter { $0.isPending }
    }

    /// 특정 방에서 분석 가능한 observation 수
    func activeObservationCount(for roomID: UUID) -> Int {
        observations(for: roomID).count
    }
}
