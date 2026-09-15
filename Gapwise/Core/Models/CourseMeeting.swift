import Foundation

enum MeetingType: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case lecture
    case tutorial
    case practical
    case other

    var id: Self { self }

    var shortName: String {
        switch self {
        case .lecture: "LEC"
        case .tutorial: "TUT"
        case .practical: "PRA"
        case .other: "Other"
        }
    }

    var displayName: String {
        switch self {
        case .lecture: "Lecture"
        case .tutorial: "Tutorial"
        case .practical: "Practical / Lab"
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

struct MeetingIdentity: Codable, Hashable, Comparable, Sendable {
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

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.sortComponents.lexicographicallyPrecedes(rhs.sortComponents)
    }

    private var sortComponents: [String] {
        [campus.rawValue, courseCode.rawValue, termID.rawValue, courseSection ?? "",
         meetingType.rawValue, meetingSection, importSourceIdentifier ?? "", sourceIdentifier]
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

enum CourseMeetingValidationError: Error, Equatable, LocalizedError {
    case emptyCourseCode
    case emptyMeetingSection
    case emptySourceIdentifier
    case endNotAfterStart
    case noMeetingDays
    case invalidTerm
    case inconsistentIdentity
    case invalidImportSource
    case differentImportedMeeting

    var errorDescription: String? {
        switch self {
        case .emptyCourseCode: "Enter a course code."
        case .emptyMeetingSection: "Enter a meeting section."
        case .emptySourceIdentifier: "The meeting has no stable source identity."
        case .endNotAfterStart: "End time must be after start time."
        case .noMeetingDays: "Select at least one meeting day."
        case .invalidTerm: "The meeting has an invalid term date range."
        case .inconsistentIdentity: "The saved meeting does not match its source identity."
        case .invalidImportSource: "The imported meeting has no valid calendar source identity."
        case .differentImportedMeeting: "Only matching imported meetings can be reconciled."
        }
    }
}

enum MeetingEditableField: String, Codable, CaseIterable, Hashable, Sendable {
    case campus
    case courseCode
    case courseTitle
    case meetingType
    case meetingSection
    case days
    case startTime
    case endTime
    case location
}

struct MeetingValues: Codable, Hashable, Sendable {
    let campus: Campus
    let courseCode: CourseCode
    let courseTitle: String?
    let meetingType: MeetingType
    let meetingSection: String
    let days: Set<Weekday>
    let startTime: LocalTime
    let endTime: LocalTime
    let location: MeetingLocation?

    init(
        campus: Campus,
        courseCode: CourseCode,
        courseTitle: String?,
        meetingType: MeetingType,
        meetingSection: String,
        days: Set<Weekday>,
        startTime: LocalTime,
        endTime: LocalTime,
        location: MeetingLocation?
    ) throws {
        let meetingSection = meetingSection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meetingSection.isEmpty else { throw CourseMeetingValidationError.emptyMeetingSection }
        guard !days.isEmpty else { throw CourseMeetingValidationError.noMeetingDays }
        guard endTime > startTime else { throw CourseMeetingValidationError.endNotAfterStart }

        self.campus = campus
        self.courseCode = courseCode
        self.courseTitle = courseTitle?.nilIfBlank
        self.meetingType = meetingType
        self.meetingSection = meetingSection.uppercased()
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
    }

    private enum CodingKeys: String, CodingKey {
        case campus
        case courseCode
        case courseTitle
        case meetingType
        case meetingSection
        case days
        case startTime
        case endTime
        case location
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            campus: container.decode(Campus.self, forKey: .campus),
            courseCode: container.decode(CourseCode.self, forKey: .courseCode),
            courseTitle: container.decodeIfPresent(String.self, forKey: .courseTitle),
            meetingType: container.decode(MeetingType.self, forKey: .meetingType),
            meetingSection: container.decode(String.self, forKey: .meetingSection),
            days: container.decode(Set<Weekday>.self, forKey: .days),
            startTime: container.decode(LocalTime.self, forKey: .startTime),
            endTime: container.decode(LocalTime.self, forKey: .endTime),
            location: container.decodeIfPresent(MeetingLocation.self, forKey: .location)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(campus, forKey: .campus)
        try container.encode(courseCode, forKey: .courseCode)
        try container.encodeIfPresent(courseTitle, forKey: .courseTitle)
        try container.encode(meetingType, forKey: .meetingType)
        try container.encode(meetingSection, forKey: .meetingSection)
        try container.encode(days.sorted { $0.rawValue < $1.rawValue }, forKey: .days)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encodeIfPresent(location, forKey: .location)
    }

    func replacing(_ other: Self, fields: Set<MeetingEditableField>) throws -> Self {
        try Self(
            campus: fields.contains(.campus) ? other.campus : campus,
            courseCode: fields.contains(.courseCode) ? other.courseCode : courseCode,
            courseTitle: fields.contains(.courseTitle) ? other.courseTitle : courseTitle,
            meetingType: fields.contains(.meetingType) ? other.meetingType : meetingType,
            meetingSection: fields.contains(.meetingSection) ? other.meetingSection : meetingSection,
            days: fields.contains(.days) ? other.days : days,
            startTime: fields.contains(.startTime) ? other.startTime : startTime,
            endTime: fields.contains(.endTime) ? other.endTime : endTime,
            location: fields.contains(.location) ? other.location : location
        )
    }

    func fieldsDiffering(from other: Self) -> Set<MeetingEditableField> {
        var fields: Set<MeetingEditableField> = []
        if campus != other.campus { fields.insert(.campus) }
        if courseCode != other.courseCode { fields.insert(.courseCode) }
        if courseTitle != other.courseTitle { fields.insert(.courseTitle) }
        if meetingType != other.meetingType { fields.insert(.meetingType) }
        if meetingSection != other.meetingSection { fields.insert(.meetingSection) }
        if days != other.days { fields.insert(.days) }
        if startTime != other.startTime { fields.insert(.startTime) }
        if endTime != other.endTime { fields.insert(.endTime) }
        if location != other.location { fields.insert(.location) }
        return fields
    }
}

struct MeetingUserOverrides: Codable, Hashable, Sendable {
    let values: MeetingValues
    let fields: Set<MeetingEditableField>

    private enum CodingKeys: String, CodingKey { case values, fields }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(values, forKey: .values)
        try container.encode(fields.sorted { $0.rawValue < $1.rawValue }, forKey: .fields)
    }
}

struct CourseMeetingEdit: Hashable, Sendable {
    let values: MeetingValues

    init(
        campus: Campus,
        courseCode: String,
        courseTitle: String?,
        meetingType: MeetingType,
        meetingSection: String,
        days: Set<Weekday>,
        startTime: LocalTime,
        endTime: LocalTime,
        location: String?
    ) throws {
        guard let courseCode = CourseCode(rawValue: courseCode) else {
            throw CourseMeetingValidationError.emptyCourseCode
        }
        values = try MeetingValues(
            campus: campus,
            courseCode: courseCode,
            courseTitle: courseTitle,
            meetingType: meetingType,
            meetingSection: meetingSection,
            days: days,
            startTime: startTime,
            endTime: endTime,
            location: UniversityLocationParser().parse(location)
        )
    }
}

struct CourseMeeting: Identifiable, Codable, Hashable, Sendable {
    let id: MeetingIdentity
    let term: AcademicTerm
    let instructor: String?
    let origin: MeetingOrigin
    let isReservedAssessmentWindow: Bool
    let sourceValues: MeetingValues
    let userOverrides: MeetingUserOverrides?
    // Validated once at construction so display never silently discards conflicting overrides.
    let effectiveValues: MeetingValues

    var campus: Campus { effectiveValues.campus }
    var courseCode: CourseCode { effectiveValues.courseCode }
    var courseTitle: String? { effectiveValues.courseTitle }
    var meetingType: MeetingType { effectiveValues.meetingType }
    var meetingSection: String { effectiveValues.meetingSection }
    var days: Set<Weekday> { effectiveValues.days }
    var startTime: LocalTime { effectiveValues.startTime }
    var endTime: LocalTime { effectiveValues.endTime }
    var location: MeetingLocation? { effectiveValues.location }
    var overriddenFields: Set<MeetingEditableField> { userOverrides?.fields ?? [] }
    var hasUserOverrides: Bool { !overriddenFields.isEmpty }

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
        origin: MeetingOrigin = .legacy,
        isReservedAssessmentWindow: Bool = false
    ) throws {
        let sourceIdentifier = sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceIdentifier.isEmpty else { throw CourseMeetingValidationError.emptySourceIdentifier }

        let sourceValues = try MeetingValues(
            campus: campus,
            courseCode: courseCode,
            courseTitle: courseTitle,
            meetingType: meetingType,
            meetingSection: meetingSection,
            days: days,
            startTime: startTime,
            endTime: endTime,
            location: location
        )
        let courseSection = courseSection?.nilIfBlank
        let id = MeetingIdentity(
            campus: campus,
            courseCode: courseCode,
            termID: term.id,
            courseSection: courseSection,
            meetingType: meetingType,
            meetingSection: sourceValues.meetingSection,
            sourceIdentifier: sourceIdentifier,
            importSourceIdentifier: origin.sourceIdentifier
        )
        try self.init(
            id: id, term: term, instructor: instructor?.nilIfBlank, origin: origin,
            sourceValues: sourceValues, userOverrides: nil,
            isReservedAssessmentWindow: isReservedAssessmentWindow
        )
    }

    func applying(_ edit: CourseMeetingEdit) throws -> Self {
        let acknowledgedFields = overriddenFields.subtracting(effectiveValues.fieldsDiffering(from: sourceValues))
        let fields = edit.values.fieldsDiffering(from: sourceValues).union(acknowledgedFields)
        return try rebuilt(sourceValues: sourceValues, overrideValues: edit.values, overrideFields: fields)
    }

    func overridingCampus(_ campus: Campus) throws -> Self {
        let current = effectiveValues
        let values = try MeetingValues(
            campus: campus,
            courseCode: current.courseCode,
            courseTitle: current.courseTitle,
            meetingType: current.meetingType,
            meetingSection: current.meetingSection,
            days: current.days,
            startTime: current.startTime,
            endTime: current.endTime,
            location: current.location
        )
        var fields = overriddenFields
        fields.insert(.campus)
        return try rebuilt(sourceValues: sourceValues, overrideValues: values, overrideFields: fields)
    }

    func acknowledgingMeetingType() throws -> Self {
        var fields = overriddenFields
        fields.insert(.meetingType)
        return try rebuilt(sourceValues: sourceValues, overrideValues: effectiveValues, overrideFields: fields)
    }

    func mergingImportedSource(_ incoming: Self) throws -> Self {
        guard let identity = ImportedMeetingIdentity(self), identity == ImportedMeetingIdentity(incoming) else {
            throw CourseMeetingValidationError.differentImportedMeeting
        }
        return try Self(
            id: incoming.id,
            term: incoming.term,
            instructor: incoming.instructor,
            origin: incoming.origin,
            sourceValues: incoming.sourceValues,
            userOverrides: userOverrides,
            isReservedAssessmentWindow: incoming.isReservedAssessmentWindow
        )
    }

    func hasSameImportedSource(as other: Self) -> Bool {
        id == other.id
            && term == other.term
            && instructor == other.instructor
            && origin == other.origin
            && sourceValues == other.sourceValues
            && isReservedAssessmentWindow == other.isReservedAssessmentWindow
    }

    private init(
        id: MeetingIdentity,
        term: AcademicTerm,
        instructor: String?,
        origin: MeetingOrigin,
        sourceValues: MeetingValues,
        userOverrides: MeetingUserOverrides?,
        isReservedAssessmentWindow: Bool
    ) throws {
        guard !id.sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CourseMeetingValidationError.emptySourceIdentifier
        }
        guard term.isValid else { throw CourseMeetingValidationError.invalidTerm }
        guard id.termID == term.id, id.campus == sourceValues.campus,
            id.courseCode == sourceValues.courseCode, id.meetingType == sourceValues.meetingType,
            id.meetingSection == sourceValues.meetingSection
        else {
            throw CourseMeetingValidationError.inconsistentIdentity
        }
        if origin.kind == .calendarImport {
            guard let source = origin.sourceIdentifier, source.nilIfBlank != nil,
                id.importSourceIdentifier == source
            else { throw CourseMeetingValidationError.invalidImportSource }
        } else if origin.sourceIdentifier != nil || id.importSourceIdentifier != nil {
            throw CourseMeetingValidationError.invalidImportSource
        }
        effectiveValues = try userOverrides.map {
            try sourceValues.replacing($0.values, fields: $0.fields)
        } ?? sourceValues
        self.id = id
        self.term = term
        self.instructor = instructor
        self.origin = origin
        self.isReservedAssessmentWindow = isReservedAssessmentWindow
        self.sourceValues = sourceValues
        self.userOverrides = userOverrides?.fields.isEmpty == false ? userOverrides : nil
    }

    private func rebuilt(
        sourceValues: MeetingValues,
        overrideValues: MeetingValues,
        overrideFields: Set<MeetingEditableField>
    ) throws -> Self {
        try Self(
            id: id,
            term: term,
            instructor: instructor,
            origin: origin,
            sourceValues: sourceValues,
            userOverrides: MeetingUserOverrides(values: overrideValues, fields: overrideFields),
            isReservedAssessmentWindow: isReservedAssessmentWindow
        )
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
        case sourceValues
        case userOverrides
        case isReservedAssessmentWindow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedID = try container.decode(MeetingIdentity.self, forKey: .id)
        let origin = try container.decodeIfPresent(MeetingOrigin.self, forKey: .origin) ?? .legacy
        // The original snapshot format omitted importSourceIdentifier and preserved section case.
        let id = MeetingIdentity(
            campus: storedID.campus, courseCode: storedID.courseCode, termID: storedID.termID,
            courseSection: storedID.courseSection?.nilIfBlank, meetingType: storedID.meetingType,
            meetingSection: storedID.meetingSection.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            sourceIdentifier: storedID.sourceIdentifier,
            importSourceIdentifier: storedID.importSourceIdentifier ?? origin.sourceIdentifier
        )
        let sourceValues: MeetingValues

        if let storedSourceValues = try container.decodeIfPresent(MeetingValues.self, forKey: .sourceValues) {
            sourceValues = storedSourceValues
        } else {
            sourceValues = try MeetingValues(
                campus: id.campus,
                courseCode: id.courseCode,
                courseTitle: try container.decodeIfPresent(String.self, forKey: .courseTitle),
                meetingType: id.meetingType,
                meetingSection: id.meetingSection,
                days: try container.decode(Set<Weekday>.self, forKey: .days),
                startTime: try container.decode(LocalTime.self, forKey: .startTime),
                endTime: try container.decode(LocalTime.self, forKey: .endTime),
                location: try container.decodeIfPresent(MeetingLocation.self, forKey: .location)
            )
        }

        try self.init(
            id: id,
            term: container.decode(AcademicTerm.self, forKey: .term),
            instructor: container.decodeIfPresent(String.self, forKey: .instructor),
            origin: origin,
            sourceValues: sourceValues,
            userOverrides: container.decodeIfPresent(MeetingUserOverrides.self, forKey: .userOverrides),
            isReservedAssessmentWindow: container.decodeIfPresent(Bool.self, forKey: .isReservedAssessmentWindow) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let effective = effectiveValues
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(effective.courseTitle, forKey: .courseTitle)
        try container.encode(term, forKey: .term)
        try container.encode(effective.days.sorted { $0.rawValue < $1.rawValue }, forKey: .days)
        try container.encode(effective.startTime, forKey: .startTime)
        try container.encode(effective.endTime, forKey: .endTime)
        try container.encodeIfPresent(effective.location, forKey: .location)
        try container.encodeIfPresent(instructor, forKey: .instructor)
        try container.encode(origin, forKey: .origin)
        try container.encode(sourceValues, forKey: .sourceValues)
        try container.encodeIfPresent(userOverrides, forKey: .userOverrides)
        try container.encode(isReservedAssessmentWindow, forKey: .isReservedAssessmentWindow)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
