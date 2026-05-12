import Combine
import Foundation

@MainActor
final class RoomRuntimeStore: ObservableObject {
    // In-memory only:
    // - active tasks
    // - active workflow step
    // - route traces
    // - last turn profile
    // - last file intake extracted text
    // - recent artifact index (room-scoped, metadata only)
    //
    // Future persistence candidates:
    // - room goal summary
    // - user-approved memory
    //
    // File 원문은 영구 저장하지 않는다.

    @Published private(set) var roomGoalContexts: [UUID: RoomGoalContext] = [:]
    @Published private(set) var lastFileIntakeResultsByRoom: [UUID: FileIntakeResult] = [:]
    @Published private(set) var activeTasksByRoom: [UUID: Task<Void, Never>] = [:]
    @Published private(set) var memoryWriteBlockedCount: Int = 0
    @Published private(set) var automationTaskSensitiveBlockedCount: Int = 0

    let recentArtifactIndex = RecentArtifactIndex()

    // RecentArtifactIndexPersistence lifecycle tracking
    var recentArtifactIndexLoadedAt: Date?
    var recentArtifactIndexLastSavedAt: Date?
    var recentArtifactIndexPersistedCount: Int = 0
    var recentArtifactIndexPersistenceError: String?

    var isAvailable: Bool { true }
    var ownsGoalContext: Bool { true }
    var ownsFileIntake: Bool { true }
    var ownsActiveTasks: Bool { true }
    var activeTaskRoomCount: Int { activeTasksByRoom.count }

    func updateRoomGoalContext(
        roomID: UUID,
        goal: GoalInterpretation? = nil,
        activeWorkflowStep: String? = nil,
        recentArtifactID: UUID? = nil
    ) {
        var context = roomGoalContexts[roomID] ?? RoomGoalContext(
            roomID: roomID,
            currentGoal: nil,
            activeWorkflowStep: nil,
            recentArtifactIDs: [],
            updatedAt: Date()
        )

        if let goal {
            context.currentGoal = goal
        }

        if let activeWorkflowStep {
            context.activeWorkflowStep = activeWorkflowStep
        }

        if let recentArtifactID {
            context.recentArtifactIDs.insert(recentArtifactID, at: 0)
            var deduped: [UUID] = []
            for artifactID in context.recentArtifactIDs {
                if !deduped.contains(artifactID) {
                    deduped.append(artifactID)
                }
                if deduped.count == 3 { break }
            }
            context.recentArtifactIDs = deduped
        }

        context.updatedAt = Date()
        roomGoalContexts[roomID] = context
    }

    func updateArtifactRuntimeStatus(
        roomID: UUID,
        persistenceStatus: ArtifactPersistenceStatusType? = nil,
        verificationStatus: VerificationStatusType? = nil,
        verificationFailureReason: String? = nil,
        planExecutionStatus: PlanExecutionStatusType? = nil
    ) {
        var context = roomGoalContexts[roomID] ?? RoomGoalContext(roomID: roomID)

        if let persistenceStatus {
            context.lastArtifactPersistenceStatus = persistenceStatus
        }

        if let verificationStatus {
            context.lastVerificationStatus = verificationStatus
        }

        if let verificationFailureReason {
            context.lastVerificationFailureReason = verificationFailureReason
        }

        if let planExecutionStatus {
            context.lastPlanExecutionStatus = planExecutionStatus
        }

        context.updatedAt = Date()
        roomGoalContexts[roomID] = context
    }

    func roomGoalContext(for roomID: UUID) -> RoomGoalContext? {
        roomGoalContexts[roomID]
    }

    func recordFileIntakeResult(_ result: FileIntakeResult, roomID: UUID) {
        lastFileIntakeResultsByRoom[roomID] = result
    }

    func recordMemoryWriteBlocked() {
        memoryWriteBlockedCount += 1
    }

    func recordAutomationTaskSensitiveBlocked() {
        automationTaskSensitiveBlockedCount += 1
    }

    func recordRecentArtifactIndexEntry(_ entry: RecentArtifactIndexEntry) {
        recentArtifactIndex.add(entry)
        saveRecentArtifactIndex()
    }

    func lastFileIntakeResult(for roomID: UUID) -> FileIntakeResult? {
        lastFileIntakeResultsByRoom[roomID]
    }

    func setActiveTask(_ task: Task<Void, Never>?, for roomID: UUID) {
        if let task {
            activeTasksByRoom[roomID] = task
        } else {
            activeTasksByRoom.removeValue(forKey: roomID)
        }
    }

    func activeTask(for roomID: UUID) -> Task<Void, Never>? {
        activeTasksByRoom[roomID]
    }

    func cancelActiveTask(for roomID: UUID) -> Task<Void, Never>? {
        let task = activeTasksByRoom.removeValue(forKey: roomID)
        task?.cancel()
        return task
    }

    func cancelAllTasks() {
        let tasks = Array(activeTasksByRoom.values)
        activeTasksByRoom.removeAll()
        tasks.forEach { $0.cancel() }
    }

    @MainActor
    func loadRecentArtifactIndex() async {
        switch RecentArtifactIndexPersistence.load() {
        case .success(let entries):
            recentArtifactIndex.clear()
            for entry in entries {
                recentArtifactIndex.add(
                    RecentArtifactIndexEntry(
                        artifactID: entry.artifactID,
                        roomID: entry.roomID,
                        filename: entry.filename,
                        artifactType: entry.artifactType,
                        createdAt: entry.createdAt,
                        contentHash: entry.contentHash.isEmpty ? nil : entry.contentHash,
                        fileSizeBytes: entry.fileSizeBytes == 0 ? nil : entry.fileSizeBytes
                    )
                )
            }
            let persistedArtifacts = await ArtifactStore.shared.loadArtifacts()
            let persistedIDs = Set(persistedArtifacts.map(\.id))
            let mismatched = entries.filter { entry in
                !persistedIDs.contains(entry.artifactID)
            }
            if !mismatched.isEmpty {
                recentArtifactIndexPersistenceError = "artifact cross-check mismatch: \(mismatched.count)"
            } else {
                recentArtifactIndexPersistenceError = nil
            }
            recentArtifactIndexLoadedAt = Date()
            recentArtifactIndexPersistedCount = entries.count
            AppLog.info("[RoomRuntimeStore] RecentArtifactIndex loaded: \(entries.count)")
        case .failure(let error):
            recentArtifactIndexLoadedAt = Date()
            recentArtifactIndexPersistedCount = recentArtifactIndex.allEntries.count
            recentArtifactIndexPersistenceError = error.message
            AppLog.warning("[RoomRuntimeStore] RecentArtifactIndex load failed: \(error.message)")
        }
    }

    @MainActor
    func saveRecentArtifactIndex() {
        let entries = recentArtifactIndex.allEntries.map {
            RecentArtifactIndexPersistenceEntry(
                artifactID: $0.artifactID,
                roomID: $0.roomID,
                filename: $0.filename,
                artifactType: $0.artifactType,
                createdAt: $0.createdAt,
                contentHash: $0.contentHash ?? "",
                fileSizeBytes: $0.fileSizeBytes ?? 0
            )
        }

        switch RecentArtifactIndexPersistence.save(entries: entries) {
        case .success:
            recentArtifactIndexLastSavedAt = Date()
            recentArtifactIndexPersistedCount = entries.count
            recentArtifactIndexPersistenceError = nil
            AppLog.debug("[RoomRuntimeStore] RecentArtifactIndex saved: \(entries.count)")
        case .failure(let error):
            recentArtifactIndexLastSavedAt = Date()
            recentArtifactIndexPersistedCount = entries.count
            recentArtifactIndexPersistenceError = error.message
            AppLog.warning("[RoomRuntimeStore] RecentArtifactIndex save failed: \(error.message)")
        }
    }
}
