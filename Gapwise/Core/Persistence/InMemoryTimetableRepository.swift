import Foundation

actor InMemoryTimetableRepository: TimetableRepository {
    private var snapshot: TimetableSnapshot

    init(snapshot: TimetableSnapshot = .empty) {
        self.snapshot = snapshot
    }

    func load() async throws -> TimetableSnapshot {
        snapshot
    }

    func save(_ snapshot: TimetableSnapshot) async throws {
        self.snapshot = snapshot
    }

    func clear() async throws {
        snapshot = .empty
    }
}
