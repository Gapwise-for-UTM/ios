import Foundation

struct LocalDate: Codable, Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

struct AcademicTerm: Codable, Hashable, Sendable {
    struct ID: RawRepresentable, Codable, Hashable, Sendable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    let id: ID
    let displayName: String
    let startsOn: LocalDate
    let endsOn: LocalDate

    init(
        id: ID,
        displayName: String,
        startsOn: LocalDate,
        endsOn: LocalDate
    ) {
        self.id = id
        self.displayName = displayName
        self.startsOn = startsOn
        self.endsOn = endsOn
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let localDate = LocalDate(date: date, calendar: calendar)
        return startsOn <= localDate && localDate <= endsOn
    }
}
