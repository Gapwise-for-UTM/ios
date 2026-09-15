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

    var isValid: Bool {
        guard (1...9999).contains(year), (1...12).contains(month), day >= 1 else { return false }
        let isLeapYear = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
        let monthLengths = [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return day <= monthLengths[month - 1]
    }

    private enum CodingKeys: String, CodingKey { case year, month, day }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            year: try container.decode(Int.self, forKey: .year),
            month: try container.decode(Int.self, forKey: .month),
            day: try container.decode(Int.self, forKey: .day)
        )
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: .day, in: container, debugDescription: "A local date must be a valid Gregorian date."
            )
        }
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

    var isValid: Bool {
        !id.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && startsOn.isValid && endsOn.isValid && startsOn <= endsOn
    }

    private enum CodingKeys: String, CodingKey { case id, displayName, startsOn, endsOn }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(ID.self, forKey: .id),
            displayName: try container.decode(String.self, forKey: .displayName),
            startsOn: try container.decode(LocalDate.self, forKey: .startsOn),
            endsOn: try container.decode(LocalDate.self, forKey: .endsOn)
        )
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: .endsOn, in: container, debugDescription: "A term needs an identity and an ordered date range."
            )
        }
    }
}
