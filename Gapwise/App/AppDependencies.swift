import Foundation

enum AppDependencies {
    @MainActor
    static func live() -> AppModel {
        let timetableRepository: any TimetableRepository
        var startupMessage: String?

        do {
            timetableRepository = try JSONTimetableRepository.applicationSupport()
        } catch {
            timetableRepository = UnavailableTimetableRepository()
            startupMessage = "Local storage is unavailable. Import will be available after storage can be opened."
        }

        return AppModel(
            timetableRepository: timetableRepository,
            preferencesRepository: UserDefaultsPreferencesRepository(),
            startupMessage: startupMessage
        )
    }
}
