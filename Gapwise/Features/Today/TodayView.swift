import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var appModel

    private let calculator = ScheduleCalculator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            todayContent(now: context.date)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Today")
    }

    private func todayContent(now: Date) -> some View {
        let meetings = calculator.meetings(on: now, in: appModel.timetable.meetings)
        let nextClass = calculator.currentOrNextClass(at: now, in: appModel.timetable.meetings)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: GapwiseSpacing.standard) {
                Text(GapwiseFormatters.fullDate(now, calendar: calculator.calendar))
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                if appModel.loadState != .ready || appModel.timetable.meetings.isEmpty {
                    TimetableAvailabilityView()
                } else if meetings.isEmpty {
                    ContentUnavailableView(
                        "No Classes Today",
                        systemImage: "sun.max",
                        description: Text("There are no classes in your saved timetable for today.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    if let nextClass {
                        nextClassCard(nextClass, now: now)
                    } else {
                        classesCompleteCard
                    }

                    Text("Today's classes")
                        .font(.headline)
                        .padding(.top, GapwiseSpacing.compact)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(meetings) { meeting in
                        MeetingCard(
                            meeting: meeting,
                            date: now,
                            isHighlighted: nextClass?.occurrence.meeting.id == meeting.id
                        )
                    }
                }
            }
            .padding(GapwiseSpacing.standard)
        }
    }

    private func nextClassCard(_ context: NextClassContext, now: Date) -> some View {
        let meeting = context.occurrence.meeting

        return VStack(alignment: .leading, spacing: GapwiseSpacing.standard) {
            HStack {
                Label(statusTitle(for: context.timing), systemImage: statusSymbol(for: context.timing))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor(for: context.timing))
                Spacer()
                Text(meeting.campus.shortName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.courseCode.rawValue)
                    .font(.title2.weight(.bold))
                if let courseTitle = meeting.courseTitle {
                    Text(courseTitle)
                        .font(.subheadline.weight(.medium))
                }
                Text(meeting.displaySection)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: GapwiseSpacing.compact) {
                Label(
                    timeRange(for: meeting, on: now),
                    systemImage: "clock"
                )
                if let location = meeting.location {
                    Label(location.displayName, systemImage: location.systemImageName)
                        .lineLimit(2)
                } else {
                    Label("Location unavailable", systemImage: "mappin.slash")
                }
            }
            .font(.subheadline)
        }
        .gapwiseCard()
        .accessibilityElement(children: .combine)
    }

    private func timeRange(for meeting: CourseMeeting, on date: Date) -> String {
        let start = GapwiseFormatters.time(meeting.startTime, on: date, calendar: calculator.calendar)
        let end = GapwiseFormatters.time(meeting.endTime, on: date, calendar: calculator.calendar)
        return "\(start)–\(end)"
    }

    private var classesCompleteCard: some View {
        Label("Classes complete for today", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(Color.gapwiseSuccess)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gapwiseCard()
    }

    private func statusTitle(for timing: ClassTiming) -> String {
        switch timing {
        case let .inProgress(minutesRemaining):
            "In progress, \(minutesRemaining) min left"
        case let .upcoming(minutesUntil):
            "Next class, \(GapwiseFormatters.relativeMinutes(minutesUntil))"
        }
    }

    private func statusSymbol(for timing: ClassTiming) -> String {
        switch timing {
        case .inProgress: "play.circle.fill"
        case .upcoming: "clock.fill"
        }
    }

    private func statusColor(for timing: ClassTiming) -> Color {
        switch timing {
        case .inProgress: Color.gapwiseSuccess
        case .upcoming: Color.gapwiseAccent
        }
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            TodayView()
                .environment(PreviewData.appModel())
        }
    }
#endif
