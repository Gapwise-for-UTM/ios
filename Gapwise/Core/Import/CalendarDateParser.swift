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
        if valueType == "DATE" || (valueType == nil && !value.contains("T") && value.count == 8) {
            guard parameters["TZID"] == nil else { return .failure(.invalidDate(value)) }
            guard let date = localDate(value) else { return .failure(.invalidDate(value)) }
            return .success(.date(date))
        }

        let timeZoneIdentifier = parameters["TZID"]
        guard timeZoneIdentifier == nil || (!value.hasSuffix("Z") && !hasNumericOffset(value)) else {
            return .failure(.invalidDate(value))
        }
        let timeZone: TimeZone
        let isFloating: Bool

        if value.hasSuffix("Z") {
            timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            isFloating = false
        } else if let timeZoneIdentifier {
            guard let resolved = resolveTimeZone(timeZoneIdentifier) else {
                return .failure(.unknownTimeZone(timeZoneIdentifier))
            }
            timeZone = resolved
            isFloating = false
        } else if hasNumericOffset(value) {
            timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            isFloating = false
        } else {
            timeZone = Calendar.gapwiseToronto.timeZone
            isFloating = true
        }

        guard let date = dateTime(value, timeZone: timeZone) else {
            return .failure(.invalidDate(value))
        }
        return .success(
            .dateTime(
                ICalendarDateTime(
                    instant: date,
                    timeZoneIdentifier: timeZoneIdentifier,
                    isFloating: isFloating
                )
            )
        )
    }

    private static func localDate(_ value: String) -> LocalDate? {
        guard value.count == 8 else { return nil }
        let formatter = formatter(format: "yyyyMMdd", timeZone: .gmt)
        guard let date = formatter.date(from: value) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        return LocalDate(year: year, month: month, day: day)
    }

    private static func dateTime(_ value: String, timeZone: TimeZone) -> Date? {
        let formats: [String]
        if hasNumericOffset(value) {
            formats = ["yyyyMMdd'T'HHmmssZ", "yyyyMMdd'T'HHmmZ"]
        } else if value.hasSuffix("Z") {
            formats = ["yyyyMMdd'T'HHmmss'Z'", "yyyyMMdd'T'HHmm'Z'"]
        } else {
            formats = ["yyyyMMdd'T'HHmmss", "yyyyMMdd'T'HHmm"]
        }

        for format in formats {
            if let date = formatter(format: format, timeZone: timeZone).date(from: value) {
                return date
            }
        }
        return nil
    }

    private static func formatter(format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }

    private static func resolveTimeZone(_ identifier: String) -> TimeZone? {
        if let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }
        if identifier.contains("America/Toronto") {
            return TimeZone(identifier: "America/Toronto")
        }
        return nil
    }

    private static func hasNumericOffset(_ value: String) -> Bool {
        guard value.count >= 5 else { return false }
        let suffix = value.suffix(5)
        guard suffix.first == "+" || suffix.first == "-" else { return false }
        return suffix.dropFirst().allSatisfy(\.isNumber)
    }
}
