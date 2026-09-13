import SwiftUI

struct TimetableImportPreviewView: View {
    @Environment(AppModel.self) private var appModel

    let plan: TimetableImportPlan

    var body: some View {
        NavigationStack {
            List {
                summarySection
                changesSection
                meetingsSection

                if !plan.draft.warnings.isEmpty {
                    warningsSection
                }
                if !plan.draft.skippedEvents.isEmpty || plan.draft.ignoredEventCount > 0 {
                    skippedSection
                }
            }
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(appModel.isSavingImport)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appModel.cancelPendingImport()
                    }
                    .disabled(appModel.isSavingImport)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await appModel.confirmPendingImport()
                        }
                    } label: {
                        if appModel.isSavingImport {
                            ProgressView()
                                .accessibilityLabel("Saving timetable")
                        } else {
                            Text("Import")
                                .bold()
                        }
                    }
                    .disabled(appModel.isSavingImport)
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            LabeledContent("Courses", value: "\(plan.draft.courseCount)")
            LabeledContent("Meetings", value: "\(plan.draft.meetings.count)")
            LabeledContent("Campuses", value: campusSummary)

            if plan.draft.unresolvedCampusCount > 0 {
                Label(
                    "\(plan.draft.unresolvedCampusCount) meeting\(plan.draft.unresolvedCampusCount == 1 ? "" : "s") need campus review.",
                    systemImage: "questionmark.circle"
                )
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(plan.draft.sourceName ?? "Calendar")
                .lineLimit(2)
        } footer: {
            Text("The calendar is processed on this device. Its original contents are not retained.")
        }
    }

    private var changesSection: some View {
        Section("Changes") {
            ChangeRow(title: "New", count: plan.changes.added, systemImage: "plus.circle.fill", tint: .gapwiseSuccess)
            ChangeRow(
                title: "Updated", count: plan.changes.updated, systemImage: "arrow.triangle.2.circlepath",
                tint: .gapwiseAccent)
            ChangeRow(
                title: "Unchanged", count: plan.changes.unchanged, systemImage: "checkmark.circle", tint: .secondary)

            if plan.changes.retainedFromPreviousImport > 0 {
                ChangeRow(
                    title: "Previously imported",
                    count: plan.changes.retainedFromPreviousImport,
                    systemImage: "archivebox",
                    tint: .secondary
                )
            }
        } footer: {
            if plan.changes.retainedFromPreviousImport > 0 {
                Text("Meetings missing from this file will remain saved until explicit removal is available.")
            }
        }
    }

    private var meetingsSection: some View {
        Section("Ready to Import") {
            ForEach(plan.draft.meetings) { meeting in
                VStack(alignment: .leading, spacing: GapwiseSpacing.compact) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(meeting.courseCode.rawValue)
                            .font(.headline)
                        Spacer()
                        Text(meeting.campus.shortName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let courseTitle = meeting.courseTitle {
                        Text(courseTitle)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                    }
                    Text(meeting.displaySection)
                        .font(.subheadline)
                    Text(scheduleSummary(for: meeting))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let location = meeting.location {
                        Label(location.displayName, systemImage: location.systemImageName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var warningsSection: some View {
        Section("Review") {
            ForEach(plan.draft.warnings) { warning in
                Label(warning.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var skippedSection: some View {
        Section("Not Imported") {
            if !plan.draft.skippedEvents.isEmpty {
                LabeledContent("Course events skipped", value: "\(plan.draft.skippedEvents.count)")
            }

            ForEach(plan.draft.skippedEvents) { event in
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(event.reason.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if plan.draft.ignoredEventCount > 0 {
                LabeledContent("Non-course events", value: "\(plan.draft.ignoredEventCount)")
            }
        }
    }

    private var campusSummary: String {
        plan.draft.campuses
            .sorted { $0.shortName < $1.shortName }
            .map(\.shortName)
            .joined(separator: ", ")
    }

    private func scheduleSummary(for meeting: CourseMeeting) -> String {
        let days = Weekday.ordered.compactMap { meeting.days.contains($0) ? $0.shortName : nil }.joined(separator: ", ")
        let start = GapwiseFormatters.time(meeting.startTime, on: .now, calendar: .gapwiseToronto)
        let end = GapwiseFormatters.time(meeting.endTime, on: .now, calendar: .gapwiseToronto)
        return "\(days) · \(start)–\(end)"
    }
}

private struct ChangeRow: View {
    let title: String
    let count: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            LabeledContent(title, value: "\(count)")
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}
