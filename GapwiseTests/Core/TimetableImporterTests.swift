import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class TimetableImporterTests: XCTestCase, @unchecked Sendable {
    func testNormalUTMImportBuildsStructuredMeetings() throws {
        let draft = try importFixture("normal-utm")

        XCTAssertEqual(draft.courseCount, 2)
        XCTAssertEqual(draft.meetings.count, 3)
        XCTAssertEqual(draft.campuses, [.utm])
        XCTAssertTrue(draft.skippedEvents.isEmpty)
        XCTAssertTrue(draft.warnings.contains { $0.kind == .assumedTorontoTime })

        let lecture = try meeting(code: "MAT157Y5", type: .lecture, in: draft)
        XCTAssertEqual(lecture.meetingSection, "LEC0101")
        XCTAssertEqual(lecture.days, [.monday, .wednesday])
        XCTAssertEqual(lecture.startTime, LocalTime(hour: 10, minute: 0))
        XCTAssertEqual(lecture.endTime, LocalTime(hour: 11, minute: 0))
        XCTAssertEqual(lecture.location?.buildingCode, "MN")
        XCTAssertEqual(lecture.location?.room, "1210")
        XCTAssertEqual(lecture.instructor, "Ada Lovelace")

        let tutorial = try meeting(code: "CSC108H5", type: .tutorial, in: draft)
        XCTAssertEqual(tutorial.location?.kind, .toBeAnnounced)

        let practical = try meeting(code: "CSC108H5", type: .practical, in: draft)
        XCTAssertEqual(practical.location?.kind, .online)
        XCTAssertEqual(practical.startTime, LocalTime(hour: 10, minute: 0))
    }

    func testImportedMeetingsDriveTodayAndNextClassCalculations() throws {
        let draft = try importFixture("normal-utm")
        let calendar = Calendar.gapwiseToronto
        let beforeLecture = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 9, minute: 30))
        )
        let calculator = ScheduleCalculator(calendar: calendar)

        let meetings = calculator.meetings(on: beforeLecture, in: draft.meetings)
        let nextClass = calculator.currentOrNextClass(at: beforeLecture, in: draft.meetings)

        XCTAssertEqual(meetings.map(\.courseCode.rawValue), ["MAT157Y5"])
        XCTAssertEqual(nextClass?.occurrence.meeting.id, meetings.first?.id)
        XCTAssertEqual(nextClass?.timing, .upcoming(minutesUntil: 30))
    }

    func testNonUTMOnlySchedulesProduceNoSupportedEvents() {
        for name in ["utsg", "utsc"] {
            XCTAssertThrowsError(try importFixture(name)) { error in
                XCTAssertEqual(error as? TimetableImportError, .noSupportedEvents)
            }
        }
    }

    func testMixedCampusImportKeepsUTMAndUnresolvedEventsAndExplainsOtherSkips() throws {
        let draft = try importFixture("mixed-campus")
        XCTAssertEqual(draft.meetings.count, 2)
        XCTAssertEqual(draft.ignoredEventCount, 1)
        XCTAssertEqual(draft.unresolvedCampusCount, 1)
        XCTAssertEqual(Set(draft.meetings.map(\.campus)), [.utm, .unknown])
        XCTAssertEqual(draft.skippedEvents.map(\.reason), [.unsupportedCampus, .unsupportedCampus])
    }

    func testMalformedAndUnsupportedEventsAreSkippedWithoutDiscardingValidMeetings() throws {
        let draft = try importFixture("malformed")

        XCTAssertEqual(draft.meetings.map(\.courseCode.rawValue), ["STA107H5"])
        XCTAssertEqual(draft.skippedEvents.count, 2)
        XCTAssertTrue(draft.skippedEvents.contains { $0.reason == .malformedDate })
        XCTAssertTrue(
            draft.skippedEvents.contains {
                if case .unsupportedRecurrence = $0.reason { return true }
                return false
            }
        )
    }

    func testFoldedUnicodeAndEscapedFixtureIsInterpreted() throws {
        let draft = try importFixture("folded-escaped")
        let meeting = try XCTUnwrap(draft.meetings.first)

        XCTAssertEqual(meeting.courseTitle, "Writing, Rhetoric; and Communication – Café")
        XCTAssertEqual(meeting.location?.displayName, "CC 1080, presentation room")
        XCTAssertEqual(meeting.instructor, "Grace Hopper")
    }

    func testEmptyCalendarProducesUnderstandableBlockingError() throws {
        XCTAssertThrowsError(try importFixture("empty")) { error in
            XCTAssertEqual(error as? TimetableImportError, .noSupportedEvents)
            XCTAssertEqual(
                (error as? LocalizedError)?.errorDescription,
                "The selected file does not contain any supported timetable events."
            )
        }
    }

    func testUnboundedAndExceptionRecurrencesAreSkipped() throws {
        let data = Data(
            calendarWithEvents([
                event(
                    uid: "unbounded",
                    codeAndSection: "MAT157Y5 LEC0101",
                    recurrence: "RRULE:FREQ=WEEKLY;BYDAY=MO"
                ),
                event(
                    uid: "exception",
                    codeAndSection: "CSC108H5 TUT0101",
                    recurrence: "RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=10\nEXDATE:20260921T100000"
                ),
                event(uid: "valid", codeAndSection: "STA107H5 PRA0101", recurrence: ""),
            ]).utf8
        )

        let document = try ICalendarParser().parse(data)
        let draft = try TimetableImporter().interpret(document, suggestedFileName: "recurrence.ics")

        XCTAssertEqual(draft.meetings.map(\.courseCode.rawValue), ["STA107H5"])
        XCTAssertEqual(draft.skippedEvents.count, 2)
    }

    func testDuplicateUIDIsIgnoredWithWarning() throws {
        let duplicate = event(uid: "same", codeAndSection: "MAT157Y5 LEC0101", recurrence: "")
        let document = try ICalendarParser().parse(Data(calendarWithEvents([duplicate, duplicate]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: "duplicate.ics")

        XCTAssertEqual(draft.meetings.count, 1)
        XCTAssertTrue(draft.warnings.contains { $0.kind == .duplicateUID })
    }

    func testDuplicateRequiredPropertiesSkipOnlyTheAffectedEvent() throws {
        let duplicateStart = event(
            uid: "duplicate-start",
            codeAndSection: "MAT157Y5 LEC0101",
            recurrence: "DTSTART;TZID=America/Toronto:20260914T120000"
        )
        let valid = event(uid: "valid", codeAndSection: "CSC108H5 TUT0101", recurrence: "")
        let document = try ICalendarParser().parse(Data(calendarWithEvents([duplicateStart, valid]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: "duplicate-property.ics")

        XCTAssertEqual(draft.meetings.map(\.courseCode.rawValue), ["CSC108H5"])
        XCTAssertEqual(draft.skippedEvents.map(\.reason), [.malformedRequiredProperty])
    }

    func testUnknownMeetingTypeProducesAReviewWarning() throws {
        let unknownType = event(uid: "seminar", codeAndSection: "MGT120H5 SEM0401", recurrence: "")
        let document = try ICalendarParser().parse(Data(calendarWithEvents([unknownType]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: "unknown-type.ics")

        XCTAssertEqual(draft.meetings.first?.meetingType, .other)
        XCTAssertTrue(draft.warnings.contains { $0.kind == .unknownMeetingType("SEM") })
    }

    func testMissingLocationProducesAReviewWarning() throws {
        let event = """
            BEGIN:VEVENT
            UID:no-location
            DTSTART;TZID=America/Toronto:20260914T100000
            DTEND;TZID=America/Toronto:20260914T110000
            SUMMARY:MAT157Y5 LEC0101 - Analysis I
            END:VEVENT
            """
        let document = try ICalendarParser().parse(Data(calendarWithEvents([event]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: "no-location.ics")

        XCTAssertNil(draft.meetings.first?.location)
        XCTAssertTrue(draft.warnings.contains { $0.kind == .missingLocation })
    }

    func testUnsafeOrIncompleteCourseEventsAreSkippedWithTypedReasons() throws {
        let allDay = """
            BEGIN:VEVENT
            UID:all-day
            DTSTART;VALUE=DATE:20260914
            DTEND;VALUE=DATE:20260915
            SUMMARY:MAT157Y5 LEC0101
            END:VEVENT
            """
        let cancelled = event(uid: "cancelled", codeAndSection: "CSC108H5 TUT0101", recurrence: "STATUS:CANCELLED")
        let missingUID = event(uid: "", codeAndSection: "STA107H5 PRA0101", recurrence: "")
        let missingEnd = """
            BEGIN:VEVENT
            UID:missing-end
            DTSTART;TZID=America/Toronto:20260914T100000
            SUMMARY:MGT120H5 LEC0101
            END:VEVENT
            """
        let valid = event(uid: "valid", codeAndSection: "ECO101H5 LEC0101", recurrence: "")
        let document = try ICalendarParser().parse(
            Data(calendarWithEvents([allDay, cancelled, missingUID, missingEnd, valid]).utf8)
        )
        let draft = try TimetableImporter().interpret(document, suggestedFileName: "invalid-events.ics")
        let reasons = Set(draft.skippedEvents.map(\.reason))

        XCTAssertEqual(draft.meetings.map(\.courseCode.rawValue), ["ECO101H5"])
        XCTAssertEqual(reasons, [.allDayEvent, .cancelled, .missingUID, .missingEndTime])
    }

    func testConflictingUIDsNeverChooseAnArbitraryFirstEvent() throws {
        let first = event(uid: "conflict", codeAndSection: "MAT157Y5 LEC0101", recurrence: "")
        let changed = first.replacingOccurrences(of: "T100000", with: "T103000")
        let valid = event(uid: "valid", codeAndSection: "CSC108H5 TUT0101", recurrence: "")
        for events in [[first, changed, valid], [changed, valid, first]] {
            let document = try ICalendarParser().parse(Data(calendarWithEvents(events).utf8))
            let draft = try TimetableImporter().interpret(document, suggestedFileName: "schedule.ics")
            XCTAssertEqual(draft.meetings.map(\.id.sourceIdentifier), ["valid"])
            XCTAssertEqual(draft.skippedEvents.map(\.reason), [.conflictingUID, .conflictingUID])
            XCTAssertEqual(draft.retainedEventUIDs, ["conflict"])
        }
    }

    func testDetachedCancelledOccurrenceDoesNotSilentlyImportItsUnmodifiedMaster() throws {
        let master = event(uid: "series", codeAndSection: "MAT157Y5 LEC0101", recurrence: "RRULE:FREQ=WEEKLY;COUNT=10")
        let exception = "BEGIN:VEVENT\nUID:series\nRECURRENCE-ID:20260921T100000\nSTATUS:CANCELLED\nEND:VEVENT"
        let valid = event(uid: "valid", codeAndSection: "CSC108H5 TUT0101", recurrence: "")
        let document = try ICalendarParser().parse(Data(calendarWithEvents([master, exception, valid]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: nil)
        XCTAssertEqual(draft.meetings.map(\.id.sourceIdentifier), ["valid"])
        XCTAssertEqual(draft.retainedEventUIDs, ["series"])
    }

    func testRecurringUTCEventsAreSkippedBecauseTorontoWeeklyTimesCannotRepresentTheirDSTShift() throws {
        let utc = event(uid: "utc", codeAndSection: "MAT157Y5 LEC0101", recurrence: "RRULE:FREQ=WEEKLY;COUNT=20")
            .replacingOccurrences(of: ";TZID=America/Toronto", with: "")
            .replacingOccurrences(of: "T100000", with: "T100000Z")
            .replacingOccurrences(of: "T110000", with: "T110000Z")
        let valid = event(uid: "valid", codeAndSection: "CSC108H5 TUT0101", recurrence: "")
        let document = try ICalendarParser().parse(Data(calendarWithEvents([utc, valid]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: nil)
        XCTAssertEqual(draft.skippedEvents.map(\.reason), [.unsupportedTimeZoneRecurrence])
        XCTAssertEqual(draft.meetings.count, 1)
    }

    func testMalformedExceptionAndEmptyRuleCannotBecomeInventedWeeklyOrSingleMeetings() throws {
        let badException = event(uid: "bad-exception", codeAndSection: "MAT157Y5 LEC0101",
            recurrence: "RRULE:FREQ=WEEKLY;COUNT=10\nEXDATE;BROKEN:20260921T100000")
        let emptyRule = event(uid: "empty-rule", codeAndSection: "MAT157Y5 TUT0101", recurrence: "RRULE:")
        let valid = event(uid: "valid", codeAndSection: "CSC108H5 TUT0101", recurrence: "")
        let document = try ICalendarParser().parse(Data(calendarWithEvents([badException, emptyRule, valid]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: nil)
        XCTAssertEqual(draft.meetings.map(\.id.sourceIdentifier), ["valid"])
        XCTAssertEqual(draft.skippedEvents.map(\.reason), [.malformedRequiredProperty, .malformedRequiredProperty])
    }

    func testFileRenameDoesNotChangeMetadataLessSourceIdentity() throws {
        let content = calendarWithEvents([event(uid: "same", codeAndSection: "MAT157Y5 LEC0101", recurrence: "")])
            .replacingOccurrences(of: "X-WR-CALNAME:UTM Timetable\n", with: "")
        let document = try ICalendarParser().parse(Data(content.utf8))
        let first = try TimetableImporter().interpret(document, suggestedFileName: "schedule.ics")
        let second = try TimetableImporter().interpret(document, suggestedFileName: "schedule (2).ics")
        XCTAssertEqual(first.sourceIdentifier, second.sourceIdentifier)
        XCTAssertFalse(first.allowsMissingEventRemoval)
    }

    func testReservedAssessmentWindowRequiresBothCanonicalACORNSignals() throws {
        let reserved = event(uid: "reserved", codeAndSection: "MAT157Y5 LEC0101",
            recurrence: "DESCRIPTION:Course title\\n********")
            .replacingOccurrences(of: "LOCATION:MN 1210", with: "LOCATION:ZZ TBA")
        let ordinary = event(uid: "ordinary", codeAndSection: "CSC108H5 TUT0101", recurrence: "")
            .replacingOccurrences(of: "LOCATION:MN 1210", with: "LOCATION:ZZ TBA")
        let document = try ICalendarParser().parse(Data(calendarWithEvents([reserved, ordinary]).utf8))
        let draft = try TimetableImporter().interpret(document, suggestedFileName: nil)
        XCTAssertTrue(try XCTUnwrap(draft.meetings.first { $0.id.sourceIdentifier == "reserved" }).isReservedAssessmentWindow)
        XCTAssertFalse(try XCTUnwrap(draft.meetings.first { $0.id.sourceIdentifier == "ordinary" }).isReservedAssessmentWindow)
    }

    private func importFixture(_ name: String) throws -> TimetableImportDraft {
        let document = try ICalendarParser().parse(FixtureLoader.data(named: name))
        return try TimetableImporter().interpret(document, suggestedFileName: "\(name).ics")
    }

    private func meeting(
        code: String,
        type: MeetingType,
        in draft: TimetableImportDraft
    ) throws -> CourseMeeting {
        try XCTUnwrap(draft.meetings.first { $0.courseCode.rawValue == code && $0.meetingType == type })
    }

    private func calendarWithEvents(_ events: [String]) -> String {
        (["BEGIN:VCALENDAR", "VERSION:2.0", "X-WR-CALNAME:UTM Timetable"] + events + ["END:VCALENDAR"])
            .joined(separator: "\n")
    }

    private func event(uid: String, codeAndSection: String, recurrence: String) -> String {
        [
            "BEGIN:VEVENT",
            "UID:\(uid)",
            "DTSTART;TZID=America/Toronto:20260914T100000",
            "DTEND;TZID=America/Toronto:20260914T110000",
            recurrence,
            "SUMMARY:\(codeAndSection)",
            "LOCATION:MN 1210",
            "END:VEVENT",
        ].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
