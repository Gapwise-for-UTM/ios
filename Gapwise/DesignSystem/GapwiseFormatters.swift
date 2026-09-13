import Foundation

enum GapwiseFormatters {
    static func time(_ time: LocalTime, on date: Date, calendar: Calendar) -> String {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute

        guard let value = calendar.date(from: components) else {
            return String(format: "%02d:%02d", time.hour, time.minute)
        }

        return value.formatted(date: .omitted, time: .shortened)
    }

    static func weekRange(_ dates: [Date], calendar: Calendar) -> String {
        guard let first = dates.first, let last = dates.last else { return "Week" }
        let firstMonth = calendar.component(.month, from: first)
        let lastMonth = calendar.component(.month, from: last)

        if firstMonth == lastMonth {
            return
                "\(first.formatted(.dateTime.month(.wide))) \(first.formatted(.dateTime.day()))-\(last.formatted(.dateTime.day()))"
        }

        return
            "\(first.formatted(.dateTime.month(.abbreviated).day())) - \(last.formatted(.dateTime.month(.abbreviated).day()))"
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
}
