import Foundation

struct ImportedMeetingIdentity: Codable, Hashable, Sendable {
    let sourceIdentifier: String
    let eventUID: String

    init(sourceIdentifier: String, eventUID: String) {
        self.sourceIdentifier = sourceIdentifier
        self.eventUID = eventUID
    }

    init?(_ meeting: CourseMeeting) {
        guard
            meeting.origin.kind == .calendarImport,
            let sourceIdentifier = meeting.origin.sourceIdentifier
        else {
            return nil
        }
        self.init(sourceIdentifier: sourceIdentifier, eventUID: meeting.id.sourceIdentifier)
    }
}

enum TimetableSourceKind: String, Codable, Hashable, Sendable {
    case calendarFile

    var displayName: String {
        switch self {
        case .calendarFile: "Calendar (.ics)"
        }
    }
}

struct TimetableSource: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let kind: TimetableSourceKind
    let displayName: String
    let lastImportedAt: Date

    init(id: String, kind: TimetableSourceKind, displayName: String?, lastImportedAt: Date) {
        self.id = id
        self.kind = kind
        self.displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Calendar"
        self.lastImportedAt = lastImportedAt
    }
}

struct CourseIdentity: Hashable, Sendable {
    let campus: Campus
    let courseCode: CourseCode
    let termID: AcademicTerm.ID

    init(_ meeting: CourseMeeting) {
        campus = meeting.campus
        courseCode = meeting.courseCode
        termID = meeting.term.id
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
