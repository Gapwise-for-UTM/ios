import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class TimetableDomainTests: XCTestCase, @unchecked Sendable {
    private let calendar = Calendar.gapwiseToronto

    func testIdentitySeparatesMatchingCourseLabelsAcrossCampuses() throws {
        let utm = try meeting(
            campus: .utm,
            code: "MAT157",
            sourceID: "shared-source",
            days: [.monday],
            start: (9, 0),
            end: (10, 0)
        )
        let utsg = try meeting(
            campus: .utsg,
            code: "MAT157",
            sourceID: "shared-source",
            days: [.monday],
            start: (9, 0),
            end: (10, 0)
        )

        XCTAssertNotEqual(utm.id, utsg.id)
        XCTAssertEqual(Set([utm, utsg]).count, 2)
    }

    func testIdentityIsStableThroughPersistenceEncoding() throws {
        let original = try meeting(
            campus: .utm,
            code: "STABLE100",
            sourceID: "stable-source",
            days: [.wednesday],
            start: (15, 0),
            end: (16, 0)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CourseMeeting.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded, original)
    }

    func testMeetingsAreFilteredByDayAndSortedByTime() throws {
        let monday = date(year: 2026, month: 9, day: 14, hour: 8)
        let late = try meeting(
            campus: .utm,
            code: "LATE200",
            sourceID: "late",
            days: [.monday],
            start: (13, 0),
            end: (14, 0)
        )
        let early = try meeting(
            campus: .utsc,
            code: "EARLY100",
            sourceID: "early",
            days: [.monday],
            start: (9, 0),
            end: (10, 0)
        )
        let tuesday = try meeting(
            campus: .utsg,
            code: "OTHER300",
            sourceID: "tuesday",
            days: [.tuesday],
            start: (8, 0),
            end: (9, 0)
        )

        let result = ScheduleCalculator(calendar: calendar).meetings(
            on: monday,
            in: [late, tuesday, early]
        )

        XCTAssertEqual(result.map(\.id), [early.id, late.id])
    }

    func testNextClassRoundsPartialMinutesUp() throws {
        let meeting = try meeting(
            campus: .utm,
            code: "NEXT100",
            sourceID: "next",
            days: [.monday],
            start: (10, 0),
            end: (11, 0)
        )
        let now = date(year: 2026, month: 9, day: 14, hour: 9, minute: 18, second: 30)

        let context = ScheduleCalculator(calendar: calendar).currentOrNextClass(at: now, in: [meeting])

        XCTAssertEqual(context?.occurrence.meeting.id, meeting.id)
        XCTAssertEqual(context?.timing, .upcoming(minutesUntil: 42))
    }

    func testCurrentClassReportsRemainingTime() throws {
        let meeting = try meeting(
            campus: .utm,
            code: "LIVE100",
            sourceID: "live",
            days: [.monday],
            start: (10, 0),
            end: (11, 0)
        )
        let now = date(year: 2026, month: 9, day: 14, hour: 10, minute: 25)

        let context = ScheduleCalculator(calendar: calendar).currentOrNextClass(at: now, in: [meeting])

        XCTAssertEqual(context?.timing, .inProgress(minutesRemaining: 35))
    }

    func testOverlappingMeetingsRemainDeterministicallyOrdered() throws {
        let first = try meeting(
            campus: .utm,
            code: "FIRST100",
            sourceID: "first",
            days: [.monday],
            start: (10, 0),
            end: (12, 0)
        )
        let second = try meeting(
            campus: .utsg,
            code: "SECOND200",
            sourceID: "second",
            days: [.monday],
            start: (10, 30),
            end: (11, 30)
        )
        let now = date(year: 2026, month: 9, day: 14, hour: 10, minute: 45)

        let context = ScheduleCalculator(calendar: calendar).currentOrNextClass(
            at: now,
            in: [second, first]
        )

        XCTAssertEqual(context?.occurrence.meeting.id, first.id)
    }

    func testAdjacentMeetingStartsWhenPreviousMeetingEnds() throws {
        let first = try meeting(
            campus: .utm,
            code: "FIRST100",
            sourceID: "first",
            days: [.monday],
            start: (10, 0),
            end: (11, 0)
        )
        let second = try meeting(
            campus: .utm,
            code: "SECOND200",
            sourceID: "second",
            days: [.monday],
            start: (11, 0),
            end: (12, 0)
        )
        let boundary = date(year: 2026, month: 9, day: 14, hour: 11)

        let context = ScheduleCalculator(calendar: calendar).currentOrNextClass(
            at: boundary,
            in: [first, second]
        )

        XCTAssertEqual(context?.occurrence.meeting.id, second.id)
        XCTAssertEqual(context?.timing, .inProgress(minutesRemaining: 60))
    }

    func testEmptyScheduleHasNoMeetingsOrNextClass() {
        let monday = date(year: 2026, month: 9, day: 14, hour: 9)
        let calculator = ScheduleCalculator(calendar: calendar)

        XCTAssertTrue(calculator.meetings(on: monday, in: []).isEmpty)
        XCTAssertNil(calculator.currentOrNextClass(at: monday, in: []))
    }

    func testWeekDatesAlwaysBeginOnMonday() {
        let sunday = date(year: 2026, month: 9, day: 13, hour: 12)
        let week = ScheduleCalculator(calendar: calendar).weekDates(containing: sunday)

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first.flatMap { Weekday(date: $0, calendar: calendar) }, .monday)
        XCTAssertEqual(week.last.flatMap { Weekday(date: $0, calendar: calendar) }, .sunday)
    }

    func testMeetingOutsideTermIsExcluded() throws {
        let meeting = try meeting(
            campus: .utm,
            code: "TERM100",
            sourceID: "term",
            days: [.monday],
            start: (9, 0),
            end: (10, 0)
        )
        let afterTerm = date(year: 2027, month: 9, day: 13, hour: 9)

        XCTAssertTrue(
            ScheduleCalculator(calendar: calendar)
                .meetings(on: afterTerm, in: [meeting])
                .isEmpty
        )
    }

    func testJSONRepositoryRoundTripAndClear() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GapwiseTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("timetable.json")
        let repository = JSONTimetableRepository(fileURL: fileURL)
        let saved = TimetableSnapshot(
            meetings: [
                try meeting(
                    campus: .utsc,
                    code: "SAVE100",
                    sourceID: "persistence",
                    days: [.friday],
                    start: (14, 0),
                    end: (15, 0)
                )
            ],
            lastModified: date(year: 2026, month: 9, day: 14, hour: 9)
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        try await repository.save(saved)
        let loaded = try await repository.load()
        XCTAssertEqual(loaded, saved)

        try await repository.clear()
        let cleared = try await repository.load()
        XCTAssertEqual(cleared, .empty)
    }

    private func meeting(
        campus: Campus,
        code: String,
        sourceID: String,
        days: Set<Weekday>,
        start: (Int, Int),
        end: (Int, Int)
    ) throws -> CourseMeeting {
        let courseCode = try XCTUnwrap(CourseCode(rawValue: code))
        let startTime = try XCTUnwrap(LocalTime(hour: start.0, minute: start.1))
        let endTime = try XCTUnwrap(LocalTime(hour: end.0, minute: end.1))
        let term = AcademicTerm(
            id: .init(rawValue: "2026-fall"),
            displayName: "Fall 2026",
            startsOn: LocalDate(year: 2026, month: 9, day: 1),
            endsOn: LocalDate(year: 2026, month: 12, day: 31)
        )

        return try CourseMeeting(
            campus: campus,
            courseCode: courseCode,
            term: term,
            courseSection: "F",
            meetingType: .lecture,
            meetingSection: "LEC0101",
            days: days,
            startTime: startTime,
            endTime: endTime,
            location: MeetingLocation(displayName: "Test Room"),
            sourceIdentifier: sourceID
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        ) ?? .distantPast
    }
}
