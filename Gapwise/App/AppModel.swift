import Foundation
import Observation
import SwiftUI

enum AppTab: Hashable {
    case today, timetable, gaps, map, settings
}

enum TimetableLoadState: Equatable {
    case notLoaded, loading, ready, failed
}

@MainActor
@Observable
final class AppModel {
    private(set) var timetable: TimetableSnapshot
    let campusIntegration: UTMCampusIntegration
    private(set) var preferences: UserPreferences
    private(set) var loadState: TimetableLoadState = .notLoaded
    private(set) var isPreparingImport = false
    private(set) var isSavingImport = false
    private(set) var isChangingTimetable = false
    private(set) var pendingImportPlan: TimetableImportPlan?
    var selectedTimetableDate: Date
    var selectedTab: AppTab = .today
    var isSelectingCalendar = false
    var alertMessage: String?

    @ObservationIgnored private let timetableRepository: any TimetableRepository
    @ObservationIgnored private let preferencesRepository: any PreferencesRepository
    @ObservationIgnored private let readDocument: @Sendable (URL, Int) async throws -> Data
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var preferencesSaveTask: Task<Void, Never>?

    init(
        timetableRepository: any TimetableRepository,
        preferencesRepository: any PreferencesRepository,
        campusIntegration: UTMCampusIntegration = .notIntegrated,
        timetable: TimetableSnapshot = .empty,
        preferences: UserPreferences = .defaults,
        selectedTimetableDate: Date = .now,
        startupMessage: String? = nil,
        now: @escaping @Sendable () -> Date = { .now },
        readDocument: @escaping @Sendable (URL, Int) async throws -> Data = {
            try await ImportedDocumentReader.read(url: $0, maximumByteCount: $1)
        }
    ) {
        self.timetableRepository = timetableRepository
        self.campusIntegration = campusIntegration
        self.preferencesRepository = preferencesRepository
        self.readDocument = readDocument
        self.now = now
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

    var isLoading: Bool { loadState == .notLoaded || loadState == .loading }
    var isBusy: Bool { isLoading || isPreparingImport || isSavingImport || isChangingTimetable }
    var canImport: Bool { loadState == .ready && !isBusy && pendingImportPlan == nil }
    var canRemoveTimetable: Bool {
        !isBusy && pendingImportPlan == nil
            && (loadState == .failed || !timetable.meetings.isEmpty || !timetable.sources.isEmpty
                || !timetable.suppressedImportedMeetings.isEmpty)
    }

    func load() async {
        guard loadState == .notLoaded || loadState == .failed, !isChangingTimetable else { return }
        loadState = .loading

        preferences = await preferencesRepository.load()

        do {
            timetable = try await timetableRepository.load()
            loadState = .ready
        } catch {
            loadState = .failed
            alertMessage = "Your saved timetable could not be loaded. The stored data has not been changed."
        }
    }

    func setAppearance(_ appearance: AppearancePreference) {
        preferences.appearance = appearance
        persistPreferences()
    }

    func requestTimetableImport() {
        guard canImport else { return }
        isSelectingCalendar = true
    }

    func clearTimetable() async {
        guard canRemoveTimetable else { return }
        isChangingTimetable = true
        defer { isChangingTimetable = false }
        do {
            try await timetableRepository.clear()
            timetable = .empty
            loadState = .ready
        } catch {
            alertMessage = "Your saved timetable could not be removed."
        }
    }

    func prepareTimetableImport(from url: URL) async {
        guard canImport else { return }
        isPreparingImport = true
        defer { isPreparingImport = false }

        do {
            let data = try await readDocument(url, TimetableImportService.maximumDocumentSize)
            let existingSnapshot = timetable
            let suggestedFileName = url.lastPathComponent
            let importedAt = now()
            pendingImportPlan = try await Task.detached(priority: .userInitiated) {
                try TimetableImportService().prepareImport(
                    data: data,
                    suggestedFileName: suggestedFileName,
                    existingSnapshot: existingSnapshot,
                    importedAt: importedAt
                )
            }.value
        } catch {
            alertMessage =
                (error as? LocalizedError)?.errorDescription
                ?? "The selected calendar could not be imported."
        }
    }

    func confirmPendingImport() async {
        guard let plan = pendingImportPlan, loadState == .ready, !isBusy else { return }
        isSavingImport = true
        defer { isSavingImport = false }

        do {
            try await timetableRepository.save(plan.resultingSnapshot)
            timetable = plan.resultingSnapshot
            pendingImportPlan = nil
            selectedTab = .timetable
        } catch {
            alertMessage = "The imported timetable could not be saved. Your existing timetable has not been changed."
        }
    }

    func removeMeeting(id: MeetingIdentity) async {
        guard canImport else { return }
        isChangingTimetable = true
        defer { isChangingTimetable = false }
        do {
            let updated = try TimetableManager().removeMeeting(id: id, from: timetable, modifiedAt: now())
            try await timetableRepository.save(updated)
            timetable = updated
        } catch {
            alertMessage = "The meeting could not be removed. Your saved timetable has not been changed."
        }
    }

    func cancelPendingImport() {
        guard !isSavingImport else { return }
        pendingImportPlan = nil
    }

    func dismissAlert() {
        alertMessage = nil
    }

    private func persistPreferences() {
        let preferences = preferences
        let repository = preferencesRepository
        let previousSave = preferencesSaveTask
        preferencesSaveTask = Task {
            await previousSave?.value
            await repository.save(preferences)
        }
    }
}
