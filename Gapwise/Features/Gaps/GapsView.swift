import SwiftUI

struct GapsView: View {
    @Environment(AppModel.self) private var appModel

    private let schedule = ScheduleCalculator()
    private let calculator = GapCalculator()

    var body: some View {
        @Bindable var appModel = appModel
        let date = appModel.selectedTimetableDate
        let gaps = calculator.gaps(on: date, in: appModel.timetable.meetings)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: GapwiseSpacing.standard) {
                DatePicker("Day", selection: $appModel.selectedTimetableDate, displayedComponents: .date)
                    .environment(\.timeZone, schedule.calendar.timeZone)
                    .environment(\.calendar, schedule.calendar)

                if appModel.loadState != .ready || appModel.timetable.meetings.isEmpty {
                    TimetableAvailabilityView()
                } else {
                    Text("Time between classes")
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Intervals of at least 5 minutes in your saved timetable. Travel time is not calculated.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if gaps.isEmpty {
                        ContentUnavailableView(
                            "No Gaps Between Classes",
                            systemImage: "hourglass",
                            description: Text("No intervals of at least 5 minutes appear between classes on this day.")
                        )
                    } else {
                        ForEach(gaps) { gap in
                            VStack(alignment: .leading, spacing: GapwiseSpacing.compact) {
                                Text("\(gap.durationMinutes) min")
                                    .font(.title2.weight(.bold))
                                Text(timeRange(gap, on: date))
                                    .font(.headline)
                                Text("After \(gap.previous.courseCode.rawValue) · Before \(gap.next.courseCode.rawValue)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .gapwiseCard()
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(GapwiseSpacing.standard)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Gaps")
    }

    private func timeRange(_ gap: TimetableGap, on date: Date) -> String {
        let start = GapwiseFormatters.time(gap.startTime, on: date, calendar: schedule.calendar)
        let end = GapwiseFormatters.time(gap.endTime, on: date, calendar: schedule.calendar)
        return "\(start)–\(end)"
    }
}
