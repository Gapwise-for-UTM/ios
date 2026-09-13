import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class ICalendarParserTests: XCTestCase, @unchecked Sendable {
    func testParsesCRLFAndLFCalendars() throws {
        let lf = minimalCalendar(lineEnding: "\n")
        let crlf = minimalCalendar(lineEnding: "\r\n")

        let lfDocument = try ICalendarParser().parse(Data(lf.utf8))
        let crlfDocument = try ICalendarParser().parse(Data(crlf.utf8))

        XCTAssertEqual(lfDocument, crlfDocument)
        XCTAssertEqual(lfDocument.events.count, 1)
    }

    func testUnfoldsLinesAndUnescapesText() throws {
        let document = try ICalendarParser().parse(FixtureLoader.data(named: "folded-escaped"))
        let event = try XCTUnwrap(document.events.first)

        XCTAssertEqual(event.summary, "ENG100H5 LEC0101 - Writing, Rhetoric; and Communication – Café")
        XCTAssertEqual(event.location, "CC 1080, presentation room")
        XCTAssertEqual(event.description, "Instructor: Grace Hopper\nBring notes; laptop")
    }

    func testUnknownFieldsAreIgnored() throws {
        let document = try ICalendarParser().parse(FixtureLoader.data(named: "folded-escaped"))

        XCTAssertEqual(document.events.count, 1)
        XCTAssertTrue(try XCTUnwrap(document.events.first).issues.isEmpty)
    }

    func testRejectsInvalidCalendarStructures() {
        let cases = [
            "not a calendar",
            "BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR",
            "BEGIN:VCALENDAR\nEND:VEVENT\nEND:VCALENDAR",
            "BEGIN:VCALENDAR\nBEGIN:VEVENT\nBEGIN:VEVENT\nEND:VEVENT\nEND:VEVENT\nEND:VCALENDAR",
            "BEGIN;X-INVALID=1:VCALENDAR\nEND:VCALENDAR",
            "BEGIN:VCALENDAR\nEND:VCALENDAR\nBEGIN:VCALENDAR\nEND:VCALENDAR",
        ]

        for value in cases {
            XCTAssertThrowsError(try ICalendarParser().parse(Data(value.utf8)), "Input: \(value)")
        }
    }

    func testRejectsInvalidUTF8AndNULBytes() {
        XCTAssertThrowsError(try ICalendarParser().parse(Data([0xFF, 0xFE]))) { error in
            XCTAssertEqual(error as? TimetableImportError, .invalidTextEncoding)
        }
        XCTAssertThrowsError(try ICalendarParser().parse(Data("BEGIN:VCALENDAR\0END:VCALENDAR".utf8))) { error in
            XCTAssertEqual(error as? TimetableImportError, .invalidTextEncoding)
        }
    }

    func testRejectsOversizedDocumentsAndLines() {
        let oversized = Data(repeating: 65, count: ICalendarParser.maximumByteCount + 1)
        XCTAssertThrowsError(try ICalendarParser().parse(oversized)) { error in
            XCTAssertEqual(
                error as? TimetableImportError,
                .documentTooLarge(maximumBytes: ICalendarParser.maximumByteCount)
            )
        }

        let longLine = "BEGIN:VCALENDAR\nX-NOTE:\(String(repeating: "a", count: 65_537))\nEND:VCALENDAR"
        XCTAssertThrowsError(try ICalendarParser().parse(Data(longLine.utf8))) { error in
            XCTAssertEqual(error as? TimetableImportError, .malformedCalendar)
        }
    }

    func testRejectsPathologicalEventCounts() {
        let event = "BEGIN:VEVENT\nUID:x\nEND:VEVENT\n"
        let calendar =
            "BEGIN:VCALENDAR\n" + String(repeating: event, count: ICalendarParser.maximumEventCount + 1)
            + "END:VCALENDAR"

        XCTAssertThrowsError(try ICalendarParser().parse(Data(calendar.utf8))) { error in
            XCTAssertEqual(
                error as? TimetableImportError,
                .tooManyEvents(maximum: ICalendarParser.maximumEventCount)
            )
        }
    }

    func testTorontoAndUTCTimestampsRepresentExpectedLocalTimeAcrossDST() throws {
        let summer = try parsedDate("20260914T100000", parameters: ["TZID": "America/Toronto"])
        let summerUTC = try parsedDate("20260914T140000Z", parameters: [:])
        let winter = try parsedDate("20260112T100000", parameters: ["TZID": "America/Toronto"])
        let winterUTC = try parsedDate("20260112T150000Z", parameters: [:])

        XCTAssertEqual(summer, summerUTC)
        XCTAssertEqual(winter, winterUTC)
    }

    func testUnknownTimezoneBecomesAnEventIssue() throws {
        let calendar = """
            BEGIN:VCALENDAR
            VERSION:2.0
            BEGIN:VEVENT
            UID:unknown-zone@example.invalid
            DTSTART;TZID=Mars/Olympus:20260914T100000
            DTEND;TZID=Mars/Olympus:20260914T110000
            SUMMARY:MAT157Y5 LEC0101
            END:VEVENT
            END:VCALENDAR
            """

        let document = try ICalendarParser().parse(Data(calendar.utf8))
        let event = try XCTUnwrap(document.events.first)

        XCTAssertNil(event.start)
        XCTAssertEqual(event.issues, [.unknownTimeZone("Mars/Olympus"), .unknownTimeZone("Mars/Olympus")])
    }

    func testRejectsConflictingOrInvalidDateParameters() {
        let cases: [(String, [String: String])] = [
            ("20260914T140000Z", ["TZID": "America/Toronto"]),
            ("20260914", ["VALUE": "DATE", "TZID": "America/Toronto"]),
            ("20260914", ["VALUE": "DATE-TIME"]),
            ("20260914T100000", ["VALUE": "TEXT"]),
        ]

        for (value, parameters) in cases {
            guard case .failure = CalendarDateParser.parse(value: value, parameters: parameters) else {
                return XCTFail("Expected \(value) with \(parameters) to fail")
            }
        }
    }

    private func parsedDate(_ value: String, parameters: [String: String]) throws -> Date {
        let parsed = CalendarDateParser.parse(value: value, parameters: parameters)
        switch parsed {
        case let .success(.dateTime(dateTime)):
            return dateTime.instant
        case .success(.date), .failure:
            return try XCTUnwrap(nil as Date?)
        }
    }

    private func minimalCalendar(lineEnding: String) -> String {
        [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "BEGIN:VEVENT",
            "UID:test@example.invalid",
            "DTSTART;TZID=America/Toronto:20260914T100000",
            "DTEND;TZID=America/Toronto:20260914T110000",
            "SUMMARY:MAT157Y5 LEC0101",
            "END:VEVENT",
            "END:VCALENDAR",
        ].joined(separator: lineEnding)
    }
}
