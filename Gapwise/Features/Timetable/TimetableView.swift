import SwiftUI

struct TimetableView: View {
    @Environment(AppModel.self) private var appModel

    private let calculator = ScheduleCalculator()

    var body: some View {
        let selectedDate = appModel.selectedTimetableDate
        let week = calculator.weekDates(containing: selectedDate)
        let meetings = calculator.meetings(on: selectedDate, in: appModel.timetable.meetings)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: GapwiseSpacing.standard) {
                weekHeader(week)

                WeekdayStrip(
                    dates: week,
                    selectedDate: selectedDate,
                    calendar: calculator.calendar,
                    onSelect: { appModel.selectedTimetableDate = $0 }
                )
                .padding(.horizontal, -GapwiseSpacing.standard)

                Divider()

                Text(GapwiseFormatters.fullDate(selectedDate, calendar: calculator.calendar))
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                if appModel.loadState != .ready || appModel.timetable.meetings.isEmpty {
                    TimetableAvailabilityView()
                } else if meetings.isEmpty {
                    emptyState(hasSavedMeetings: !appModel.timetable.meetings.isEmpty)
                } else {
                    ForEach(meetings) { meeting in
                        NavigationLink {
                            MeetingDetailView(meetingID: meeting.id)
                        } label: {
                            MeetingCard(meeting: meeting, date: selectedDate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(GapwiseSpacing.standard)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Timetable")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    appModel.selectedTimetableDate = calculator.date(
                        byAddingDays: -7,
                        to: appModel.selectedTimetableDate
                    )
                } label: {
                    Label("Previous week", systemImage: "chevron.left")
                }

                Button("Today") {
                    appModel.selectedTimetableDate = .now
                }

                Button {
                    appModel.selectedTimetableDate = calculator.date(
                        byAddingDays: 7,
                        to: appModel.selectedTimetableDate
                    )
                } label: {
                    Label("Next week", systemImage: "chevron.right")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button { appModel.requestTimetableImport() } label: {
                    Label("Import Calendar", systemImage: "square.and.arrow.down")
                }
                .disabled(!appModel.canImport)
            }
        }
    }

    private func weekHeader(_ dates: [Date]) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Week of")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(GapwiseFormatters.weekRange(dates, calendar: calculator.calendar))
                    .font(.title2.weight(.bold))
            }
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(Color.gapwiseAccent)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func emptyState(hasSavedMeetings: Bool) -> some View {
        if hasSavedMeetings {
            ContentUnavailableView(
                "No Classes",
                systemImage: "calendar.badge.checkmark",
                description: Text("Nothing is scheduled for this day.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ContentUnavailableView(
                "No Saved Timetable",
                systemImage: "calendar",
                description: Text("Your saved classes will appear here.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        }
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            TimetableView()
                .environment(PreviewData.appModel())
        }
    }
#endif
