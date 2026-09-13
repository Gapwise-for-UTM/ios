import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class TimetableReconcilerTests: XCTestCase, @unchecked Sendable {
    func testImportingSameTimetableTwiceDoesNotDuplicateMeetings() throws {
        let service = TimetableImportService()
        let data = try FixtureLoader.data(named: "normal-utm")
        let first = try service.prepareImport(
            data: data,
            suggestedFileName: "schedule.ics",
            existingSnapshot: .empty,
            importedAt: date(hour: 9)
        )
        let second = try service.prepareImport(
            data: data,
            suggestedFileName: "schedule.ics",
            existingSnapshot: first.resultingSnapshot,
            importedAt: date(hour: 10)
        )

        XCTAssertEqual(first.changes.added, 3)
        XCTAssertEqual(second.changes.added, 0)
        XCTAssertEqual(second.changes.updated, 0)
        XCTAssertEqual(second.changes.unchanged, 3)
        XCTAssertEqual(second.resultingSnapshot.meetings.count, 3)
    }

    func testNewerImportUpdatesMatchingUIDAndConservativelyRetainsMissingMeeting() throws {
        let service = TimetableImportService()
        let first = try service.prepareImport(
            data: FixtureLoader.data(named: "update-v1"),
            suggestedFileName: "schedule.ics",
            existingSnapshot: .empty,
            importedAt: date(hour: 9)
        )
        let second = try service.prepareImport(
            data: FixtureLoader.data(named: "update-v2"),
            suggestedFileName: "schedule.ics",
            existingSnapshot: first.resultingSnapshot,
            importedAt: date(hour: 10)
        )

        XCTAssertEqual(second.changes.updated, 1)
        XCTAssertEqual(second.changes.retainedFromPreviousImport, 1)
        XCTAssertEqual(second.resultingSnapshot.meetings.count, 2)

        let updated = try XCTUnwrap(
            second.resultingSnapshot.meetings.first { $0.id.sourceIdentifier == "update-primary@example.invalid" }
        )
        XCTAssertEqual(updated.startTime, LocalTime(hour: 10, minute: 30))
        XCTAssertEqual(updated.location?.room, "2110")
    }

    func testImportedAndLegacyMeetingsRemainSeparate() throws {
        let imported = try TimetableImportService().prepareImport(
            data: FixtureLoader.data(named: "normal-utm"),
            suggestedFileName: "schedule.ics",
            existingSnapshot: .empty
        )
        let legacy = try makeMeeting(sourceIdentifier: "local-entry", origin: .manual)
        let existing = TimetableSnapshot(meetings: imported.resultingSnapshot.meetings + [legacy])
        let repeated = try TimetableImportService().prepareImport(
            data: FixtureLoader.data(named: "normal-utm"),
            suggestedFileName: "schedule.ics",
            existingSnapshot: existing
        )

        XCTAssertEqual(repeated.resultingSnapshot.meetings.count, 4)
        XCTAssertTrue(repeated.resultingSnapshot.meetings.contains(legacy))
    }

    func testSameUIDFromDifferentImportSourcesHasDistinctIdentity() throws {
        let first = try makeMeeting(
            sourceIdentifier: "shared-uid", origin: .calendarImport(sourceIdentifier: "source-a"))
        let second = try makeMeeting(
            sourceIdentifier: "shared-uid", origin: .calendarImport(sourceIdentifier: "source-b"))

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(Set([first, second]).count, 2)
    }

    func testLegacySnapshotWithoutNewMetadataStillDecodes() throws {
        let original = try makeMeeting(sourceIdentifier: "legacy-id", origin: .legacy)
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "origin")
        var identifier = try XCTUnwrap(object["id"] as? [String: Any])
        identifier.removeValue(forKey: "importSourceIdentifier")
        object["id"] = identifier
        if var location = object["location"] as? [String: Any] {
            location.removeValue(forKey: "rawLocation")
            location.removeValue(forKey: "kind")
            object["location"] = location
        }

        let decoded = try JSONDecoder().decode(CourseMeeting.self, from: JSONSerialization.data(withJSONObject: object))

        XCTAssertEqual(decoded.origin, .legacy)
        XCTAssertNil(decoded.id.importSourceIdentifier)
        XCTAssertEqual(decoded.location?.rawLocation, decoded.location?.displayName)
        XCTAssertEqual(decoded.location?.kind, .unknown)
    }

    func testImportedSnapshotPersistsThroughRepositoryRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GapwiseImportTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("timetable.json")
        let repository = JSONTimetableRepository(fileURL: fileURL)
        defer { try? FileManager.default.removeItem(at: directory) }

        let plan = try TimetableImportService().prepareImport(
            data: FixtureLoader.data(named: "mixed-campus"),
            suggestedFileName: "schedule.ics",
            existingSnapshot: .empty,
            importedAt: date(hour: 9)
        )
        try await repository.save(plan.resultingSnapshot)

        let relaunchedRepository = JSONTimetableRepository(fileURL: fileURL)
        let loaded = try await relaunchedRepository.load()

        XCTAssertEqual(loaded, plan.resultingSnapshot)
    }

    private func makeMeeting(sourceIdentifier: String, origin: MeetingOrigin) throws -> CourseMeeting {
        try CourseMeeting(
            campus: .utm,
            courseCode: XCTUnwrap(CourseCode(rawValue: "MAT157Y5")),
            term: AcademicTerm(
                id: .init(rawValue: "2026-fall"),
                displayName: "Fall 2026",
                startsOn: LocalDate(year: 2026, month: 9, day: 1),
                endsOn: LocalDate(year: 2026, month: 12, day: 31)
            ),
            meetingType: .lecture,
            meetingSection: "LEC0101",
            days: [.monday],
            startTime: XCTUnwrap(LocalTime(hour: 10, minute: 0)),
            endTime: XCTUnwrap(LocalTime(hour: 11, minute: 0)),
            location: MeetingLocation(displayName: "MN 1210"),
            sourceIdentifier: sourceIdentifier,
            origin: origin
        )
    }

    private func date(hour: Int) -> Date {
        Calendar.gapwiseToronto.date(
            from: DateComponents(year: 2026, month: 9, day: 14, hour: hour)
        ) ?? .distantPast
    }
}
