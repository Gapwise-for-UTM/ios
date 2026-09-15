import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class GapCalculatorTests: XCTestCase {
    private let calendar = Calendar.gapwiseToronto
    private var calculator: GapCalculator { GapCalculator(calendar: calendar) }
    private var monday: Date { date(2026, 9, 14) }

    func testEmptyAndSingleMeetingHaveNoInventedDayEdgeGaps() throws {
        XCTAssertTrue(calculator.gaps(on: monday, in: []).isEmpty)
        XCTAssertTrue(calculator.gaps(on: monday, in: [try meeting("only", 540, 600)]).isEmpty)
    }

    func testReportsRawBoundariesAndDurationWithoutSubtractingTravel() throws {
        let first = try meeting("first", 540, 600)
        let next = try meeting("next", 660, 720)
        let gap = try XCTUnwrap(calculator.gaps(on: monday, in: [first, next]).first)

        XCTAssertEqual(gap.previous, first)
        XCTAssertEqual(gap.next, next)
        XCTAssertEqual(gap.startTime.minutesSinceMidnight, 600)
        XCTAssertEqual(gap.endTime.minutesSinceMidnight, 660)
        XCTAssertEqual(gap.durationMinutes, 60)
    }

    func testNestedMeetingsDoNotCreateFalseFreeTime() throws {
        let outer = try meeting("outer", 540, 720)
        let nested = try meeting("nested", 600, 660)
        let next = try meeting("next", 780, 840)
        let gaps = calculator.gaps(on: monday, in: [outer, nested, next])

        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps.first?.previous, outer)
        XCTAssertEqual(gaps.first?.durationMinutes, 60)
    }

    func testOverlappingChainRetainsLatestOccupiedEndAndItsMeeting() throws {
        let first = try meeting("first", 540, 660)
        let second = try meeting("second", 600, 720)
        let extending = try meeting("extending", 690, 780)
        let next = try meeting("next", 810, 840)
        let gaps = calculator.gaps(on: monday, in: [first, second, extending, next])

        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps.first?.previous, extending)
        XCTAssertEqual(gaps.first?.durationMinutes, 30)
    }

    func testTouchingAndSubFiveMinuteIntervalsAreNotGaps() throws {
        let first = try meeting("first", 540, 600)
        let touching = try meeting("touching", 600, 660)
        let near = try meeting("near", 664, 720)
        let next = try meeting("next", 725, 780)
        let gaps = calculator.gaps(on: monday, in: [first, touching, near, next])

        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps.first?.previous, near)
        XCTAssertEqual(gaps.first?.durationMinutes, 5)
    }

    func testPreservesAllSeparateQualifyingGapsInTimeOrder() throws {
        let schedule = [
            try meeting("late", 900, 960),
            try meeting("first", 540, 600),
            try meeting("middle", 720, 780),
        ]
        let gaps = calculator.gaps(on: monday, in: schedule)

        XCTAssertEqual(gaps.map(\.startTime.minutesSinceMidnight), [600, 780])
        XCTAssertEqual(gaps.map(\.durationMinutes), [120, 120])
        XCTAssertNotEqual(gaps[0].id, gaps[1].id)
    }

    func testEveryInputPermutationProducesIdenticalContextsAndIdentities() throws {
        let first = try meeting("same-event", 540, 660, source: "a")
        let tied = try meeting("same-event", 540, 660, source: "b")
        let nested = try meeting("nested", 600, 630)
        let next = try meeting("next", 720, 780)
        let schedule = [first, tied, nested, next]
        let expected = calculator.gaps(on: monday, in: schedule)

        XCTAssertEqual(expected.first?.previous, first)
        for input in permutations(schedule) {
            XCTAssertEqual(calculator.gaps(on: monday, in: input), expected)
        }
    }

    func testOnlyRequestedWeekdayAndInclusiveImportedDateRangeParticipate() throws {
        let singleDay = term(start: LocalDate(year: 2026, month: 9, day: 14),
                             end: LocalDate(year: 2026, month: 9, day: 14))
        let first = try meeting("first", 540, 600, term: singleDay)
        let next = try meeting("next", 660, 720, term: singleDay)
        let tuesday = try meeting("other-day", 600, 660, days: [.tuesday])
        let schedule = [first, next, tuesday]

        XCTAssertEqual(calculator.gaps(on: monday, in: schedule).count, 1)
        XCTAssertTrue(calculator.gaps(on: date(2026, 9, 7), in: schedule).isEmpty)
        XCTAssertTrue(calculator.gaps(on: date(2026, 9, 21), in: schedule).isEmpty)
        XCTAssertTrue(calculator.gaps(on: date(2026, 9, 15), in: schedule).isEmpty)
    }

    func testTorontoDayAndGapIdentityRemainStableAcrossDSTAndUTCDateBoundary() throws {
        let before = try meeting("first", 540, 600, days: [.sunday])
        let after = try meeting("next", 660, 720, days: [.sunday])
        let schedule = [before, after]
        let morning = calculator.gaps(on: date(2026, 11, 1, hour: 0), in: schedule)
        // 23:00 Toronto is already November 2 in UTC after the fall clock change.
        let evening = calculator.gaps(on: date(2026, 11, 1, hour: 23), in: schedule)
        let followingWeek = calculator.gaps(on: date(2026, 11, 8), in: schedule)

        XCTAssertEqual(morning, evening)
        XCTAssertEqual(morning.first?.durationMinutes, 60)
        XCTAssertEqual(morning.first?.id.date, LocalDate(year: 2026, month: 11, day: 1))
        XCTAssertNotEqual(morning.first?.id, followingWeek.first?.id)
        XCTAssertTrue(calculator.gaps(on: date(2026, 11, 2, hour: 0), in: schedule).isEmpty)
    }

    func testReservedAssessmentSuppressesWholeCandidateInsteadOfBecomingGapAnchor() throws {
        let first = try meeting("first", 540, 600)
        let reserved = try meeting("reserved", 660, 720, reserved: true)
        let next = try meeting("next", 780, 840)

        XCTAssertTrue(calculator.gaps(on: monday, in: [first, reserved, next]).isEmpty)
        XCTAssertTrue(calculator.gaps(on: monday, in: [reserved, next]).isEmpty)
        XCTAssertTrue(calculator.gaps(on: monday, in: [first, reserved]).isEmpty)
    }

    func testReservedAssessmentBoundaryTouchDoesNotSuppressUnoccupiedGap() throws {
        let first = try meeting("first", 540, 600)
        let next = try meeting("next", 660, 720)
        let before = try meeting("reserved-before", 570, 600, reserved: true)
        let after = try meeting("reserved-after", 660, 690, reserved: true)
        let gaps = calculator.gaps(on: monday, in: [first, next, before, after])

        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps.first?.durationMinutes, 60)
    }

    private func meeting(
        _ identifier: String, _ start: Int, _ end: Int,
        days: Set<Weekday> = [.monday], source: String = "acorn", term: AcademicTerm? = nil,
        reserved: Bool = false
    ) throws -> CourseMeeting {
        try CourseMeeting(
            campus: .utm,
            courseCode: XCTUnwrap(CourseCode(rawValue: "CSC108H5")),
            term: term ?? self.term(),
            meetingType: .lecture,
            meetingSection: "LEC0101",
            days: days,
            startTime: XCTUnwrap(LocalTime(hour: start / 60, minute: start % 60)),
            endTime: XCTUnwrap(LocalTime(hour: end / 60, minute: end % 60)),
            sourceIdentifier: identifier,
            origin: .calendarImport(sourceIdentifier: source),
            isReservedAssessmentWindow: reserved
        )
    }

    private func term(
        start: LocalDate = LocalDate(year: 2026, month: 9, day: 1),
        end: LocalDate = LocalDate(year: 2026, month: 12, day: 31)
    ) -> AcademicTerm {
        AcademicTerm(id: .init(rawValue: "2026-fall"), displayName: "Fall 2026", startsOn: start, endsOn: end)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func permutations<T>(_ values: [T]) -> [[T]] {
        guard !values.isEmpty else { return [[]] }
        return values.indices.flatMap { index in
            var rest = values
            let first = rest.remove(at: index)
            return permutations(rest).map { [first] + $0 }
        }
    }
}
