import Foundation

enum ClassTiming: Equatable, Sendable {
    case inProgress(minutesRemaining: Int)
    case upcoming(minutesUntil: Int)
}

struct ScheduledOccurrence: Equatable, Sendable {
    let meeting: CourseMeeting
    let interval: DateInterval
}

struct NextClassContext: Equatable, Sendable {
    let occurrence: ScheduledOccurrence
    let timing: ClassTiming
}

struct ScheduleCalculator: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .gapwiseToronto) {
        self.calendar = calendar
    }

    func meetings(on date: Date, in schedule: [CourseMeeting]) -> [CourseMeeting] {
        guard let weekday = Weekday(date: date, calendar: calendar) else { return [] }

        return
            schedule
            .filter { meeting in
                meeting.days.contains(weekday) && meeting.term.contains(date, calendar: calendar)
            }
            .sorted(by: Self.meetingOrder)
    }

    func occurrences(on date: Date, in schedule: [CourseMeeting]) -> [ScheduledOccurrence] {
        meetings(on: date, in: schedule).compactMap { meeting in
            guard let interval = interval(for: meeting, on: date) else { return nil }
            return ScheduledOccurrence(meeting: meeting, interval: interval)
        }
    }

    func currentOrNextClass(at date: Date, in schedule: [CourseMeeting]) -> NextClassContext? {
        for occurrence in occurrences(on: date, in: schedule) {
            if occurrence.interval.start <= date && date < occurrence.interval.end {
                let minutes = wholeMinutes(from: date, to: occurrence.interval.end)
                return NextClassContext(
                    occurrence: occurrence,
                    timing: .inProgress(minutesRemaining: minutes)
                )
            }

            if occurrence.interval.start > date {
                let minutes = wholeMinutes(from: date, to: occurrence.interval.start)
                return NextClassContext(
                    occurrence: occurrence,
                    timing: .upcoming(minutesUntil: minutes)
                )
            }
        }

        return nil
    }

    func weekDates(containing date: Date) -> [Date] {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysSinceMonday = (weekday + 5) % 7

        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) else {
            return [startOfDay]
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    func date(byAddingDays days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func interval(for meeting: CourseMeeting, on date: Date) -> DateInterval? {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        var startComponents = day
        startComponents.hour = meeting.startTime.hour
        startComponents.minute = meeting.startTime.minute

        var endComponents = day
        endComponents.hour = meeting.endTime.hour
        endComponents.minute = meeting.endTime.minute

        guard
            let start = calendar.date(from: startComponents),
            let end = calendar.date(from: endComponents),
            end > start
        else {
            return nil
        }

        return DateInterval(start: start, end: end)
    }

    private func wholeMinutes(from start: Date, to end: Date) -> Int {
        let seconds = max(0, end.timeIntervalSince(start))
        let minutes = seconds / 60
        return Int(ceil(minutes))
    }

    private static func meetingOrder(_ lhs: CourseMeeting, _ rhs: CourseMeeting) -> Bool {
        if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
        if lhs.endTime != rhs.endTime { return lhs.endTime < rhs.endTime }
        if lhs.courseCode != rhs.courseCode { return lhs.courseCode < rhs.courseCode }
        if lhs.campus != rhs.campus { return lhs.campus.rawValue < rhs.campus.rawValue }
        return lhs.id < rhs.id
    }
}

extension Calendar {
    static var gapwiseToronto: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_CA")
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? .gmt
        return calendar
    }
}
