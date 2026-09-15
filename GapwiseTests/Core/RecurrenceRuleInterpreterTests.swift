import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class RecurrenceRuleInterpreterTests: XCTestCase, @unchecked Sendable {
    private let calendar = Calendar.gapwiseToronto

    func testCountAcrossMultipleWeekdaysEndsOnExactOccurrence() throws {
        let recurrence = try RecurrenceRuleInterpreter(calendar: calendar).interpret(
            "FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4",
            startingAt: date(year: 2026, month: 9, day: 14, hour: 10)
        )

        XCTAssertEqual(recurrence.days, [.monday, .wednesday])
        XCTAssertEqual(recurrence.endsOn, LocalDate(year: 2026, month: 9, day: 23))
    }

    func testUntilBeforeMeetingTimeDoesNotIncludeAnExtraOccurrence() throws {
        let recurrence = try RecurrenceRuleInterpreter(calendar: calendar).interpret(
            "FREQ=WEEKLY;BYDAY=MO;UNTIL=20260921T130000Z",
            startingAt: date(year: 2026, month: 9, day: 14, hour: 10)
        )

        XCTAssertEqual(recurrence.endsOn, LocalDate(year: 2026, month: 9, day: 20))
    }

    func testUnboundedDuplicateAndNonWeeklyRulesAreRejected() {
        let start = date(year: 2026, month: 9, day: 14, hour: 10)
        let rules = [
            "FREQ=WEEKLY;BYDAY=MO",
            "FREQ=WEEKLY;BYDAY=MO;BYDAY=TU;COUNT=10",
            "FREQ=DAILY;COUNT=10",
            "FREQ=WEEKLY;INTERVAL=2;COUNT=10",
            "FREQ=WEEKLY;BYDAY=MO,;COUNT=10",
            "FREQ=WEEKLY;BYDAY=,MO;COUNT=10",
            "FREQ=WEEKLY;BYDAY=MO;COUNT=0",
            "FREQ=WEEKLY;BYDAY=MO;UNTIL=20260230",
        ]

        for rule in rules {
            XCTAssertThrowsError(try RecurrenceRuleInterpreter(calendar: calendar).interpret(rule, startingAt: start))
        }
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }
}
