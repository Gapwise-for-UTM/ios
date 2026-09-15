import SwiftUI

/// Shared presentation for unavailable local state; an unreadable schedule is never a free day.
struct TimetableAvailabilityView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if appModel.isLoading {
            ProgressView("Loading timetable")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if appModel.loadState == .failed {
            ContentUnavailableView {
                Label("Timetable Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Your saved timetable could not be opened. Its stored data has been preserved.")
            } actions: {
                Button("Retry Loading") { Task { await appModel.load() } }
            }
        } else {
            ContentUnavailableView {
                Label("No Saved Timetable", systemImage: "calendar")
            } description: {
                Text("Import your UTM timetable from an ACORN .ics export to see classes and time between them.")
            } actions: {
                Button("Import Calendar File") { appModel.requestTimetableImport() }
                    .disabled(!appModel.canImport)
            }
        }
    }
}
