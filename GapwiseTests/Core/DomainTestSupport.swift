import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

enum DomainTestSupport {
    static let modifiedAt = Date(timeIntervalSince1970: 1_800_000_000)

    static func meeting(
        uid: String = "event-one",
        source: String? = "acorn-utm",
        code: String = "CSC108H5",
        title: String? = "Introduction to Computer Programming",
        campus: Campus = .utm,
        type: MeetingType = .lecture,
        days: Set<Weekday> = [.monday, .wednesday],
        start: Int = 9,
        end: Int = 10,
        assessment: Bool = false
    ) throws -> CourseMeeting {
        try CourseMeeting(
            campus: campus,
            courseCode: XCTUnwrap(CourseCode(rawValue: code)),
            courseTitle: title,
            term: AcademicTerm(
                id: .init(rawValue: "2026-fall"), displayName: "Fall 2026",
                startsOn: LocalDate(year: 2026, month: 9, day: 1),
                endsOn: LocalDate(year: 2026, month: 12, day: 31)
            ),
            meetingType: type,
            meetingSection: "0101",
            days: days,
            startTime: XCTUnwrap(LocalTime(hour: start, minute: 0)),
            endTime: XCTUnwrap(LocalTime(hour: end, minute: 0)),
            sourceIdentifier: uid,
            origin: source.map(MeetingOrigin.calendarImport) ?? .manual,
            isReservedAssessmentWindow: assessment
        )
    }

    static func edit(
        _ meeting: CourseMeeting,
        title: String? = nil,
        start: Int? = nil,
        end: Int? = nil,
        code: String? = nil
    ) throws -> CourseMeetingEdit {
        try CourseMeetingEdit(
            campus: meeting.campus, courseCode: code ?? meeting.courseCode.rawValue,
            courseTitle: title ?? meeting.courseTitle,
            meetingType: meeting.meetingType, meetingSection: meeting.meetingSection, days: meeting.days,
            startTime: start.flatMap { LocalTime(hour: $0, minute: 0) } ?? meeting.startTime,
            endTime: end.flatMap { LocalTime(hour: $0, minute: 0) } ?? meeting.endTime,
            location: meeting.location?.rawLocation
        )
    }

    static func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    static func decode<T: Decodable>(_ type: T.Type, object: [String: Any]) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: object))
    }
}
