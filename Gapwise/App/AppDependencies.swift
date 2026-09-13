import Foundation

enum AppDependencies {
    @MainActor
    static func live() -> AppModel {
        let timetableRepository: any TimetableRepository
        var startupMessage: String?

        do {
            timetableRepository = try JSONTimetableRepository.applicationSupport()
        } catch {
            timetableRepository = InMemoryTimetableRepository()
            startupMessage = "Local storage is temporarily unavailable. Changes made in this session may not persist."
        }

        return AppModel(
            timetableRepository: timetableRepository,
            preferencesRepository: UserDefaultsPreferencesRepository(),
            startupMessage: startupMessage
        )
    }
}
