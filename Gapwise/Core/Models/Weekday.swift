import Foundation

enum Weekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    static let ordered: [Self] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    init?(date: Date, calendar: Calendar) {
        self.init(rawValue: calendar.component(.weekday, from: date))
    }
}
