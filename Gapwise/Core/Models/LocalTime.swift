import Foundation

struct LocalTime: Codable, Hashable, Comparable, Sendable {
    let minutesSinceMidnight: Int

    var hour: Int { minutesSinceMidnight / 60 }
    var minute: Int { minutesSinceMidnight % 60 }

    init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else {
            return nil
        }

        self.init(validatedMinutes: hour * 60 + minute)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    private init(validatedMinutes: Int) {
        minutesSinceMidnight = validatedMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case hour
        case minute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hour = try container.decode(Int.self, forKey: .hour)
        let minute = try container.decode(Int.self, forKey: .minute)

        guard let time = Self(hour: hour, minute: minute) else {
            throw DecodingError.dataCorruptedError(
                forKey: .hour,
                in: container,
                debugDescription: "A local time must be between 00:00 and 23:59."
            )
        }

        self = time
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
    }
}
