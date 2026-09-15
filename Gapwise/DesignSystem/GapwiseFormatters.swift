import Foundation

enum GapwiseFormatters {
    static func time(_ time: LocalTime, on date: Date, calendar: Calendar) -> String {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute

        guard let value = calendar.date(from: components) else {
            return String(format: "%02d:%02d", time.hour, time.minute)
        }

        let format = Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: .current,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        return format.format(value)
    }

    static func fullDate(_ date: Date, calendar: Calendar) -> String {
        dateFormat(calendar: calendar)
            .weekday(.wide)
            .month(.wide)
            .day()
            .format(date)
    }

    static func narrowWeekday(_ date: Date, calendar: Calendar) -> String {
        dateFormat(calendar: calendar).weekday(.narrow).format(date)
    }

    static func dayNumber(_ date: Date, calendar: Calendar) -> String {
        dateFormat(calendar: calendar).day().format(date)
    }

    static func weekRange(_ dates: [Date], calendar: Calendar) -> String {
        guard let first = dates.first, let last = dates.last else { return "Week" }
        let firstMonth = calendar.component(.month, from: first)
        let lastMonth = calendar.component(.month, from: last)

        if firstMonth == lastMonth {
            let format = dateFormat(calendar: calendar)
            return "\(format.month(.wide).format(first)) \(format.day().format(first))-\(format.day().format(last))"
        }

        let format = dateFormat(calendar: calendar).month(.abbreviated).day()
        return "\(format.format(first)) - \(format.format(last))"
    }

    static func relativeMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "in \(minutes) min"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "in \(hours) hr"
        }
        return "in \(hours) hr \(remainingMinutes) min"
    }

    private static func dateFormat(calendar: Calendar) -> Date.FormatStyle {
        Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: .current,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
    }
}
