import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    private(set) var timetable: TimetableSnapshot
    private(set) var preferences: UserPreferences
    private(set) var isLoading = false
    var selectedTimetableDate: Date
    var alertMessage: String?

    @ObservationIgnored private let timetableRepository: any TimetableRepository
    @ObservationIgnored private let preferencesRepository: any PreferencesRepository
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var preferencesSaveTask: Task<Void, Never>?

    init(
        timetableRepository: any TimetableRepository,
        preferencesRepository: any PreferencesRepository,
        timetable: TimetableSnapshot = .empty,
        preferences: UserPreferences = .defaults,
        selectedTimetableDate: Date = .now,
        startupMessage: String? = nil
    ) {
        self.timetableRepository = timetableRepository
        self.preferencesRepository = preferencesRepository
        self.timetable = timetable
        self.preferences = preferences
        self.selectedTimetableDate = selectedTimetableDate
        alertMessage = startupMessage
    }

    var preferredColorScheme: ColorScheme? {
        switch preferences.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }

        preferences = await preferencesRepository.load()

        do {
            timetable = try await timetableRepository.load()
        } catch {
            alertMessage = "Your saved timetable could not be loaded. The stored data has not been changed."
        }
    }

    func setAppearance(_ appearance: AppearancePreference) {
        preferences.appearance = appearance
        persistPreferences()
    }

    func setCampusContext(_ campus: Campus) {
        preferences.campusContext = campus
        persistPreferences()
    }

    func clearTimetable() async {
        do {
            try await timetableRepository.clear()
            timetable = .empty
        } catch {
            alertMessage = "Your saved timetable could not be removed."
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }

    private func persistPreferences() {
        let preferences = preferences
        let repository = preferencesRepository
        preferencesSaveTask?.cancel()
        preferencesSaveTask = Task {
            guard !Task.isCancelled else { return }
            await repository.save(preferences)
        }
    }
}
