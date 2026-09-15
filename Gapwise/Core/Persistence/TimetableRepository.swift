import Foundation

protocol TimetableRepository: Sendable {
    func load() async throws -> TimetableSnapshot
    func save(_ snapshot: TimetableSnapshot) async throws
    func clear() async throws
}

enum TimetableRepositoryError: Error, Equatable, LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        "Local timetable storage is unavailable. Try opening the app again."
    }
}

// Fail visibly when the persistent location cannot be created; never report an in-memory save as durable.
struct UnavailableTimetableRepository: TimetableRepository {
    let error: TimetableRepositoryError

    init(error: TimetableRepositoryError = .applicationSupportUnavailable) {
        self.error = error
    }

    func load() async throws -> TimetableSnapshot { throw error }
    func save(_ snapshot: TimetableSnapshot) async throws { throw error }
    func clear() async throws { throw error }
}
