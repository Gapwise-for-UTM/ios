import Foundation

enum MeetingType: String, Codable, CaseIterable, Hashable, Sendable {
    case lecture
    case tutorial
    case practical
    case other

    var shortName: String {
        switch self {
        case .lecture: "LEC"
        case .tutorial: "TUT"
        case .practical: "PRA"
        case .other: "Other"
        }
    }
}

struct CourseCode: RawRepresentable, Codable, Hashable, Comparable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return nil }
        self.rawValue = normalized
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let code = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "A course code cannot be empty."
            )
        }
        self = code
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct MeetingIdentity: Codable, Hashable, Sendable {
    let campus: Campus
    let courseCode: CourseCode
    let termID: AcademicTerm.ID
    let courseSection: String
    let meetingType: MeetingType
    let meetingSection: String
    let sourceIdentifier: String
}

struct MeetingLocation: Codable, Hashable, Sendable {
    let displayName: String
    let buildingCode: String?
    let room: String?

    init(displayName: String, buildingCode: String? = nil, room: String? = nil) {
        self.displayName = displayName
        self.buildingCode = buildingCode
        self.room = room
    }
}

enum CourseMeetingValidationError: Error, Equatable {
    case emptyCourseSection
    case emptyMeetingSection
    case emptySourceIdentifier
    case endNotAfterStart
    case noMeetingDays
}

struct CourseMeeting: Identifiable, Codable, Hashable, Sendable {
    let id: MeetingIdentity
    let courseTitle: String?
    let term: AcademicTerm
    let days: Set<Weekday>
    let startTime: LocalTime
    let endTime: LocalTime
    let location: MeetingLocation?
    let instructor: String?

    var campus: Campus { id.campus }
    var courseCode: CourseCode { id.courseCode }
    var meetingType: MeetingType { id.meetingType }
    var meetingSection: String { id.meetingSection }

    init(
        campus: Campus,
        courseCode: CourseCode,
        courseTitle: String? = nil,
        term: AcademicTerm,
        courseSection: String,
        meetingType: MeetingType,
        meetingSection: String,
        days: Set<Weekday>,
        startTime: LocalTime,
        endTime: LocalTime,
        location: MeetingLocation? = nil,
        instructor: String? = nil,
        sourceIdentifier: String
    ) throws {
        let courseSection = courseSection.trimmingCharacters(in: .whitespacesAndNewlines)
        let meetingSection = meetingSection.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceIdentifier = sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !courseSection.isEmpty else {
            throw CourseMeetingValidationError.emptyCourseSection
        }
        guard !meetingSection.isEmpty else {
            throw CourseMeetingValidationError.emptyMeetingSection
        }
        guard !sourceIdentifier.isEmpty else {
            throw CourseMeetingValidationError.emptySourceIdentifier
        }
        guard endTime > startTime else {
            throw CourseMeetingValidationError.endNotAfterStart
        }
        guard !days.isEmpty else {
            throw CourseMeetingValidationError.noMeetingDays
        }

        id = MeetingIdentity(
            campus: campus,
            courseCode: courseCode,
            termID: term.id,
            courseSection: courseSection,
            meetingType: meetingType,
            meetingSection: meetingSection,
            sourceIdentifier: sourceIdentifier
        )
        self.courseTitle = courseTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.term = term
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.instructor = instructor?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case courseTitle
        case term
        case days
        case startTime
        case endTime
        case location
        case instructor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(MeetingIdentity.self, forKey: .id)

        try self.init(
            campus: id.campus,
            courseCode: id.courseCode,
            courseTitle: try container.decodeIfPresent(String.self, forKey: .courseTitle),
            term: try container.decode(AcademicTerm.self, forKey: .term),
            courseSection: id.courseSection,
            meetingType: id.meetingType,
            meetingSection: id.meetingSection,
            days: try container.decode(Set<Weekday>.self, forKey: .days),
            startTime: try container.decode(LocalTime.self, forKey: .startTime),
            endTime: try container.decode(LocalTime.self, forKey: .endTime),
            location: try container.decodeIfPresent(MeetingLocation.self, forKey: .location),
            instructor: try container.decodeIfPresent(String.self, forKey: .instructor),
            sourceIdentifier: id.sourceIdentifier
        )
    }
}
