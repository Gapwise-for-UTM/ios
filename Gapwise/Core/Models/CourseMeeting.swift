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
    let courseSection: String?
    let meetingType: MeetingType
    let meetingSection: String
    let sourceIdentifier: String
    let importSourceIdentifier: String?

    init(
        campus: Campus,
        courseCode: CourseCode,
        termID: AcademicTerm.ID,
        courseSection: String?,
        meetingType: MeetingType,
        meetingSection: String,
        sourceIdentifier: String,
        importSourceIdentifier: String? = nil
    ) {
        self.campus = campus
        self.courseCode = courseCode
        self.termID = termID
        self.courseSection = courseSection
        self.meetingType = meetingType
        self.meetingSection = meetingSection
        self.sourceIdentifier = sourceIdentifier
        self.importSourceIdentifier = importSourceIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case campus
        case courseCode
        case termID
        case courseSection
        case meetingType
        case meetingSection
        case sourceIdentifier
        case importSourceIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        campus = try container.decode(Campus.self, forKey: .campus)
        courseCode = try container.decode(CourseCode.self, forKey: .courseCode)
        termID = try container.decode(AcademicTerm.ID.self, forKey: .termID)
        courseSection = try container.decodeIfPresent(String.self, forKey: .courseSection)
        meetingType = try container.decode(MeetingType.self, forKey: .meetingType)
        meetingSection = try container.decode(String.self, forKey: .meetingSection)
        sourceIdentifier = try container.decode(String.self, forKey: .sourceIdentifier)
        importSourceIdentifier = try container.decodeIfPresent(String.self, forKey: .importSourceIdentifier)
    }
}

enum MeetingLocationKind: String, Codable, Hashable, Sendable {
    case physical
    case online
    case toBeAnnounced
    case unknown
}

struct MeetingLocation: Codable, Hashable, Sendable {
    let displayName: String
    let rawLocation: String
    let buildingCode: String?
    let room: String?
    let kind: MeetingLocationKind

    init(
        displayName: String,
        rawLocation: String? = nil,
        buildingCode: String? = nil,
        room: String? = nil,
        kind: MeetingLocationKind = .unknown
    ) {
        self.displayName = displayName
        self.rawLocation = rawLocation ?? displayName
        self.buildingCode = buildingCode
        self.room = room
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case displayName
        case rawLocation
        case buildingCode
        case room
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decode(String.self, forKey: .displayName)
        rawLocation = try container.decodeIfPresent(String.self, forKey: .rawLocation) ?? displayName
        buildingCode = try container.decodeIfPresent(String.self, forKey: .buildingCode)
        room = try container.decodeIfPresent(String.self, forKey: .room)
        kind = try container.decodeIfPresent(MeetingLocationKind.self, forKey: .kind) ?? .unknown
    }
}

enum MeetingOriginKind: String, Codable, Hashable, Sendable {
    case calendarImport
    case manual
    case legacy
}

struct MeetingOrigin: Codable, Hashable, Sendable {
    let kind: MeetingOriginKind
    let sourceIdentifier: String?

    static let legacy = MeetingOrigin(kind: .legacy, sourceIdentifier: nil)
    static let manual = MeetingOrigin(kind: .manual, sourceIdentifier: nil)

    static func calendarImport(sourceIdentifier: String) -> Self {
        MeetingOrigin(kind: .calendarImport, sourceIdentifier: sourceIdentifier)
    }
}

enum CourseMeetingValidationError: Error, Equatable {
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
    let origin: MeetingOrigin

    var campus: Campus { id.campus }
    var courseCode: CourseCode { id.courseCode }
    var meetingType: MeetingType { id.meetingType }
    var meetingSection: String { id.meetingSection }

    var displaySection: String {
        let normalizedSection = meetingSection.uppercased()
        let knownPrefixes = ["LEC", "TUT", "PRA", "LAB"]
        if knownPrefixes.contains(where: normalizedSection.hasPrefix) {
            return normalizedSection
        }
        return "\(meetingType.shortName) \(meetingSection)"
    }

    init(
        campus: Campus,
        courseCode: CourseCode,
        courseTitle: String? = nil,
        term: AcademicTerm,
        courseSection: String? = nil,
        meetingType: MeetingType,
        meetingSection: String,
        days: Set<Weekday>,
        startTime: LocalTime,
        endTime: LocalTime,
        location: MeetingLocation? = nil,
        instructor: String? = nil,
        sourceIdentifier: String,
        origin: MeetingOrigin = .legacy
    ) throws {
        let courseSection = courseSection?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meetingSection = meetingSection.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceIdentifier = sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

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
            courseSection: courseSection?.isEmpty == false ? courseSection : nil,
            meetingType: meetingType,
            meetingSection: meetingSection,
            sourceIdentifier: sourceIdentifier,
            importSourceIdentifier: origin.sourceIdentifier
        )
        self.courseTitle = courseTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.term = term
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.instructor = instructor?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.origin = origin
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
        case origin
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
            sourceIdentifier: id.sourceIdentifier,
            origin: try container.decodeIfPresent(MeetingOrigin.self, forKey: .origin) ?? .legacy
        )
    }
}
