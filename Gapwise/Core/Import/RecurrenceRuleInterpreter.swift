import Foundation

struct WeeklyRecurrence: Equatable, Sendable {
    let days: Set<Weekday>
    let endsOn: LocalDate
}

struct RecurrenceRuleInterpreter: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .gapwiseToronto) {
        self.calendar = calendar
    }

    func interpret(_ rawRule: String, startingAt start: Date) throws -> WeeklyRecurrence {
        var values: [String: String] = [:]
        for component in rawRule.split(separator: ";", omittingEmptySubsequences: false) {
            let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { throw SkippedEventReason.unsupportedRecurrence(rawRule) }
            let key = String(pair[0]).uppercased()
            guard !key.isEmpty, values[key] == nil else {
                throw SkippedEventReason.unsupportedRecurrence(rawRule)
            }
            values[key] = String(pair[1])
        }

        let supportedKeys: Set<String> = ["FREQ", "INTERVAL", "BYDAY", "UNTIL", "COUNT", "WKST"]
        guard Set(values.keys).isSubset(of: supportedKeys), values["FREQ"]?.uppercased() == "WEEKLY" else {
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }

        if let interval = values["INTERVAL"], interval != "1" {
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }
        if let weekStart = values["WKST"], try parseDays(weekStart, rawRule: rawRule).count != 1 {
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }
        guard values["UNTIL"] == nil || values["COUNT"] == nil else {
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }

        let startWeekday = Weekday(date: start, calendar: calendar)
        let days: Set<Weekday>
        if let byDay = values["BYDAY"] {
            let parsed = try parseDays(byDay, rawRule: rawRule)
            guard let startWeekday, parsed.contains(startWeekday) else {
                throw SkippedEventReason.unsupportedRecurrence(rawRule)
            }
            days = parsed
        } else if let startWeekday {
            days = [startWeekday]
        } else {
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }

        let endsOn: LocalDate
        if let until = values["UNTIL"] {
            endsOn = try endDate(from: until, start: start, days: days, rawRule: rawRule)
        } else if let rawCount = values["COUNT"], let count = Int(rawCount), (1...10_000).contains(count) {
            endsOn = try endDate(forOccurrenceCount: count, start: start, days: days, rawRule: rawRule)
        } else {
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }

        guard LocalDate(date: start, calendar: calendar) <= endsOn else {
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }
        return WeeklyRecurrence(days: days, endsOn: endsOn)
    }

    private func parseDays(_ value: String, rawRule: String) throws -> Set<Weekday> {
        var days: Set<Weekday> = []
        for token in value.split(separator: ",") {
            let day: Weekday?
            switch token.uppercased() {
            case "SU": day = .sunday
            case "MO": day = .monday
            case "TU": day = .tuesday
            case "WE": day = .wednesday
            case "TH": day = .thursday
            case "FR": day = .friday
            case "SA": day = .saturday
            default: day = nil
            }
            guard let day else { throw SkippedEventReason.unsupportedRecurrence(rawRule) }
            days.insert(day)
        }
        guard !days.isEmpty else { throw SkippedEventReason.unsupportedRecurrence(rawRule) }
        return days
    }

    private func endDate(
        from value: String,
        start: Date,
        days: Set<Weekday>,
        rawRule: String
    ) throws -> LocalDate {
        switch CalendarDateParser.parse(value: value, parameters: [:]) {
        case let .success(.date(date)):
            return date
        case let .success(.dateTime(dateTime)):
            let boundaryDate = LocalDate(date: dateTime.instant, calendar: calendar)
            guard
                let boundaryWeekday = Weekday(date: dateTime.instant, calendar: calendar),
                days.contains(boundaryWeekday),
                let occurrence = occurrence(on: boundaryDate, atSameLocalTimeAs: start),
                occurrence > dateTime.instant,
                let previousDay = calendar.date(byAdding: .day, value: -1, to: dateTime.instant)
            else {
                return boundaryDate
            }
            return LocalDate(date: previousDay, calendar: calendar)
        case .failure:
            throw SkippedEventReason.unsupportedRecurrence(rawRule)
        }
    }

    private func occurrence(on date: LocalDate, atSameLocalTimeAs start: Date) -> Date? {
        let startTime = calendar.dateComponents([.hour, .minute, .second], from: start)
        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: date.year,
                month: date.month,
                day: date.day,
                hour: startTime.hour,
                minute: startTime.minute,
                second: startTime.second
            )
        )
    }

    private func endDate(
        forOccurrenceCount count: Int,
        start: Date,
        days: Set<Weekday>,
        rawRule: String
    ) throws -> LocalDate {
        var candidate = calendar.startOfDay(for: start)
        var occurrenceCount = 0
        let maximumDays = count * 7 + 7

        for _ in 0..<maximumDays {
            if let weekday = Weekday(date: candidate, calendar: calendar), days.contains(weekday) {
                occurrenceCount += 1
                if occurrenceCount == count {
                    return LocalDate(date: candidate, calendar: calendar)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                throw SkippedEventReason.unsupportedRecurrence(rawRule)
            }
            candidate = next
        }

        throw SkippedEventReason.unsupportedRecurrence(rawRule)
    }
}
