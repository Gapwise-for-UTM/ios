import Foundation

enum CalendarDateParser {
    static func parse(
        value: String,
        parameters: [String: String]
    ) -> Result<ICalendarTemporalValue, ICalendarEventIssue> {
        let valueType = parameters["VALUE"]?.uppercased()
        guard valueType == nil || valueType == "DATE" || valueType == "DATE-TIME" else {
            return .failure(.invalidDate(value))
        }
        if valueType == "DATE" || (valueType == nil && value.count == 8) {
            guard parameters["TZID"] == nil, let components = dateComponents(value),
                let date = validatedDate(components, timeZone: .gmt) else {
                return .failure(.invalidDate(value))
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            return .success(.date(LocalDate(date: date, calendar: calendar)))
        }

        let timeZoneIdentifier = parameters["TZID"]
        let isUTC = value.hasSuffix("Z")
        guard !isUTC || timeZoneIdentifier == nil else { return .failure(.invalidDate(value)) }
        let timeZone: TimeZone
        if isUTC {
            timeZone = .gmt
        } else if let timeZoneIdentifier {
            guard let resolved = TimeZone(identifier: timeZoneIdentifier) else {
                return .failure(.unknownTimeZone(timeZoneIdentifier))
            }
            timeZone = resolved
        } else {
            timeZone = Calendar.gapwiseToronto.timeZone
        }
        let localValue = isUTC ? String(value.dropLast()) : value
        // Numeric offsets are not an iCalendar DATE-TIME representation (RFC 5545 §3.3.5).
        guard let components = dateTimeComponents(localValue),
            let instant = validatedDate(components, timeZone: timeZone) else {
            return .failure(.invalidDate(value))
        }
        return .success(.dateTime(ICalendarDateTime(
            instant: instant,
            timeZoneIdentifier: timeZoneIdentifier,
            isFloating: !isUTC && timeZoneIdentifier == nil
        )))
    }

    private static func dateComponents(_ value: String) -> DateComponents? {
        let bytes = Array(value.utf8)
        guard bytes.count == 8, bytes.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return DateComponents(
            year: number(bytes[0..<4]), month: number(bytes[4..<6]), day: number(bytes[6..<8])
        )
    }

    private static func dateTimeComponents(_ value: String) -> DateComponents? {
        let bytes = Array(value.utf8)
        guard (bytes.count == 15 || bytes.count == 13), bytes[8] == 84,
            let prefix = String(bytes: bytes[0..<8], encoding: .utf8),
            var components = dateComponents(prefix),
            bytes[9...].allSatisfy({ (48...57).contains($0) }) else { return nil }
        components.hour = number(bytes[9..<11])
        components.minute = number(bytes[11..<13])
        components.second = bytes.count == 15 ? number(bytes[13..<15]) : 0
        return components
    }

    private static func number(_ digits: ArraySlice<UInt8>) -> Int {
        digits.reduce(0) { $0 * 10 + Int($1 - 48) }
    }

    private static func validatedDate(_ components: DateComponents, timeZone: TimeZone) -> Date? {
        guard let year = components.year, (1...9999).contains(year),
            let month = components.month, (1...12).contains(month),
            let day = components.day, (1...31).contains(day),
            (0...23).contains(components.hour ?? 0),
            (0...59).contains(components.minute ?? 0),
            (0...59).contains(components.second ?? 0) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: components) else { return nil }
        // Calendar normalizes e.g. February 30 and times inside a DST gap. Reject both.
        let actual = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard actual.year == year, actual.month == month, actual.day == day,
            actual.hour == (components.hour ?? 0), actual.minute == (components.minute ?? 0),
            actual.second == (components.second ?? 0) else { return nil }
        return date
    }
}
