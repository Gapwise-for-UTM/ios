import Foundation

protocol TimetableRepository: Sendable {
    func load() async throws -> TimetableSnapshot
    func save(_ snapshot: TimetableSnapshot) async throws
    func clear() async throws
}

enum TimetableRepositoryError: Error {
    case applicationSupportUnavailable
}
