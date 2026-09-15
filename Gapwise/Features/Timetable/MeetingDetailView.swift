import SwiftUI

struct MeetingDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingRemoval = false

    let meetingID: MeetingIdentity

    private var meeting: CourseMeeting? {
        appModel.timetable.meetings.first { $0.id == meetingID }
    }

    var body: some View {
        List {
            if let meeting {
                Section("Class") {
                    Text(meeting.courseCode.rawValue).font(.headline)
                    if let title = meeting.courseTitle { Text(title) }
                    LabeledContent("Section", value: meeting.displaySection)
                    LabeledContent("Campus", value: meeting.campus.shortName)
                    Text(meeting.location?.displayName ?? "Location not provided")
                    Text(scheduleSummary(meeting))
                        .foregroundStyle(.secondary)
                    Text("Times are shown in Toronto time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                let issues = TimetableReviewService().issues(for: meeting)
                if !issues.isEmpty {
                    Section("Source Details to Review") {
                        ForEach(issues) { issue in
                            Label(issue.message, systemImage: "info.circle")
                        }
                    }
                }

                Section {
                    Button("Remove Meeting", role: .destructive) { isConfirmingRemoval = true }
                        .disabled(!appModel.canImport)
                } footer: {
                    Text("Removing an imported meeting also keeps it hidden when the same source event is imported again.")
                }
            } else {
                Text("This meeting is no longer in your saved timetable.")
            }
        }
        .navigationTitle("Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove this meeting?", isPresented: $isConfirmingRemoval, titleVisibility: .visible
        ) {
            Button("Remove Meeting", role: .destructive) {
                Task {
                    await appModel.removeMeeting(id: meetingID)
                    if meeting == nil { dismiss() }
                }
            }
        }
    }

    private func scheduleSummary(_ meeting: CourseMeeting) -> String {
        let days = Weekday.ordered.filter { meeting.days.contains($0) }.map(\.fullName).joined(separator: ", ")
        let date = appModel.selectedTimetableDate
        let start = GapwiseFormatters.time(meeting.startTime, on: date, calendar: .gapwiseToronto)
        let end = GapwiseFormatters.time(meeting.endTime, on: date, calendar: .gapwiseToronto)
        return "\(days) · \(start)–\(end)"
    }
}
