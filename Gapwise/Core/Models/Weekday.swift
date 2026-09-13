import Foundation

enum Weekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    init?(date: Date, calendar: Calendar) {
        self.init(rawValue: calendar.component(.weekday, from: date))
    }
}
