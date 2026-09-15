import Foundation

/// A raw interval between scheduled commitments. It contains no travel or activity estimate.
struct TimetableGap: Identifiable, Equatable, Sendable {
    struct ID: Hashable, Sendable {
        let date: LocalDate
        let previousMeetingID: MeetingIdentity
        let nextMeetingID: MeetingIdentity
    }

    let id: ID
    let previous: CourseMeeting
    let next: CourseMeeting

    var startTime: LocalTime { previous.endTime }
    var endTime: LocalTime { next.startTime }
    var durationMinutes: Int { endTime.minutesSinceMidnight - startTime.minutesSinceMidnight }

    fileprivate init(date: LocalDate, previous: CourseMeeting, next: CourseMeeting) {
        id = ID(date: date, previousMeetingID: previous.id, nextMeetingID: next.id)
        self.previous = previous
        self.next = next
    }
}

struct GapCalculator: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .gapwiseToronto) {
        self.calendar = calendar
    }

    /// Mirrors gapwise/src/lib/gaps.ts at ec6f5ebeeffab8d6c2f663756d9a3f63cd833c83:
    /// merge occupied intervals, require five minutes, and exclude reserved assessment windows.
    /// Durations are timetable minute-of-day differences, without routing or usability claims.
    func gaps(on date: Date, in schedule: [CourseMeeting]) -> [TimetableGap] {
        let day = ScheduleCalculator(calendar: calendar).meetings(on: date, in: schedule)
        let reserved = day.filter(\.isReservedAssessmentWindow)
        let commitments = day.filter { !$0.isReservedAssessmentWindow }.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
            if lhs.endTime != rhs.endTime { return lhs.endTime > rhs.endTime }
            return lhs.id < rhs.id
        }
        guard var previous = commitments.first else { return [] }

        let localDate = LocalDate(date: date, calendar: calendar)
        var gaps: [TimetableGap] = []

        for next in commitments.dropFirst() {
            if next.startTime <= previous.endTime {
                if next.endTime > previous.endTime { previous = next }
                continue
            }

            let duration = next.startTime.minutesSinceMidnight - previous.endTime.minutesSinceMidnight
            if duration >= 5,
                !reserved.contains(where: { $0.startTime < next.startTime && $0.endTime > previous.endTime })
            {
                gaps.append(TimetableGap(date: localDate, previous: previous, next: next))
            }
            previous = next
        }

        return gaps
    }
}
