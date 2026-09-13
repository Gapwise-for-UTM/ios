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
                Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                if appModel.isLoading && appModel.timetable.meetings.isEmpty {
                    ProgressView("Loading today")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if meetings.isEmpty {
                    ContentUnavailableView(
                        "No Classes Today",
                        systemImage: "sun.max",
                        description: Text("Your day is clear.")
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
                Text("\(meeting.meetingType.shortName) \(meeting.meetingSection)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: GapwiseSpacing.standard) {
                Label(
                    GapwiseFormatters.time(meeting.startTime, on: now, calendar: calculator.calendar),
                    systemImage: "clock"
                )
                if let location = meeting.location {
                    Label(location.displayName, systemImage: "mappin")
                        .lineLimit(2)
                }
            }
            .font(.subheadline)
        }
        .gapwiseCard()
        .accessibilityElement(children: .combine)
    }

    private var classesCompleteCard: some View {
        Label("Classes complete for today", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(.gapwiseSuccess)
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
        case .inProgress: .gapwiseSuccess
        case .upcoming: .gapwiseAccent
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
