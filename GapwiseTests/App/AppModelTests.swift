import Foundation
import XCTest
@testable import Gapwise

/// These exercise native app state in the Xcode test target; SwiftPM tests cover the portable core.
final class AppModelTests: XCTestCase, @unchecked Sendable {
    @MainActor
    func testFailedLoadBlocksImportAndCanRetryWithoutReplacingStoredData() async throws {
        let repository = ControlledTimetableRepository()
        await repository.setLoadFailure(true)
        let model = makeModel(repository: repository)

        await model.load()
        XCTAssertEqual(model.loadState, .failed)
        XCTAssertFalse(model.canImport)
        await model.prepareTimetableImport(from: URL(fileURLWithPath: "/unused.ics"))
        XCTAssertNil(model.pendingImportPlan)

        await repository.setLoadFailure(false)
        await model.load()
        XCTAssertEqual(model.loadState, .ready)
        XCTAssertTrue(model.canImport)
        let saves = await repository.saveCount
        XCTAssertEqual(saves, 0)
    }

    @MainActor
    func testPreviewDoesNotPersistAndBlocksRemovalUntilCancelled() async throws {
        let repository = ControlledTimetableRepository()
        let model = makeModel(repository: repository)
        await model.load()
        await model.prepareTimetableImport(from: URL(fileURLWithPath: "/timetable.ics"))

        XCTAssertNotNil(model.pendingImportPlan)
        XCTAssertTrue(model.timetable.meetings.isEmpty)
        XCTAssertFalse(model.canRemoveTimetable)
        await model.clearTimetable()
        let clears = await repository.clearCount
        XCTAssertEqual(clears, 0)
        let saves = await repository.saveCount
        XCTAssertEqual(saves, 0)

        model.cancelPendingImport()
        XCTAssertNil(model.pendingImportPlan)
        XCTAssertTrue(model.canImport)
    }

    @MainActor
    func testSaveFailureKeepsPreviewAndPreviousStateForRetry() async throws {
        let repository = ControlledTimetableRepository()
        let model = makeModel(repository: repository)
        await model.load()
        await model.prepareTimetableImport(from: URL(fileURLWithPath: "/timetable.ics"))
        await repository.setSaveFailure(true)
        await model.confirmPendingImport()

        XCTAssertNotNil(model.pendingImportPlan)
        XCTAssertTrue(model.timetable.meetings.isEmpty)
        XCTAssertNotNil(model.alertMessage)
        XCTAssertFalse(model.isSavingImport)

        await repository.setSaveFailure(false)
        await model.confirmPendingImport()
        XCTAssertNil(model.pendingImportPlan)
        XCTAssertEqual(model.timetable.meetings.count, 1)
        XCTAssertEqual(model.selectedTab, .timetable)
        XCTAssertEqual(model.timetable.lastModified, Date(timeIntervalSince1970: 1_800_000_000))
        let saved = try await repository.load()
        XCTAssertEqual(saved, model.timetable)
    }

    @MainActor
    func testImportReadBlocksClearAndSecondImport() async throws {
        let repository = ControlledTimetableRepository()
        let reader = SuspendedDocumentRead()
        let model = AppModel(
            timetableRepository: repository,
            preferencesRepository: InMemoryPreferencesRepository(),
            readDocument: { _, _ in try await reader.read() }
        )
        await model.load()
        let task = Task { await model.prepareTimetableImport(from: URL(fileURLWithPath: "/first.ics")) }
        await reader.waitUntilStarted()
        XCTAssertTrue(model.isPreparingImport)
        XCTAssertFalse(model.canImport)
        await model.clearTimetable()
        await model.prepareTimetableImport(from: URL(fileURLWithPath: "/second.ics"))
        let clears = await repository.clearCount
        XCTAssertEqual(clears, 0)
        let reads = await reader.readCount
        XCTAssertEqual(reads, 1)
        await reader.finish(with: Data(Self.calendar.utf8))
        await task.value
        XCTAssertNotNil(model.pendingImportPlan)
        XCTAssertFalse(model.isPreparingImport)
    }

    @MainActor
    func testRemovingImportedMeetingPersistsSuppression() async throws {
        let repository = ControlledTimetableRepository()
        let model = makeModel(repository: repository)
        await model.load()
        await model.prepareTimetableImport(from: URL(fileURLWithPath: "/timetable.ics"))
        await model.confirmPendingImport()
        let id = try XCTUnwrap(model.timetable.meetings.first?.id)

        await model.removeMeeting(id: id)
        XCTAssertTrue(model.timetable.meetings.isEmpty)
        XCTAssertEqual(model.timetable.suppressedImportedMeetings.count, 1)
        await model.prepareTimetableImport(from: URL(fileURLWithPath: "/timetable.ics"))
        XCTAssertEqual(model.pendingImportPlan?.changes.suppressed, 1)
    }

    @MainActor
    private func makeModel(repository: ControlledTimetableRepository) -> AppModel {
        AppModel(
            timetableRepository: repository,
            preferencesRepository: InMemoryPreferencesRepository(),
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            readDocument: { _, _ in Data(Self.calendar.utf8) }
        )
    }

    private static let calendar = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Gapwise//Synthetic App Tests//EN
        X-WR-CALNAME:UTM Test Timetable
        BEGIN:VEVENT
        UID:app-test
        SUMMARY:CSC108H5 F LEC0101
        DTSTART;TZID=America/Toronto:20260914T090000
        DTEND;TZID=America/Toronto:20260914T100000
        LOCATION:DH 2060
        END:VEVENT
        END:VCALENDAR
        """
}

private enum TestFailure: Error { case storage }

private actor ControlledTimetableRepository: TimetableRepository {
    private var snapshot: TimetableSnapshot = .empty
    private var failsLoad = false
    private var failsSave = false
    private(set) var saveCount = 0
    private(set) var clearCount = 0

    func setLoadFailure(_ value: Bool) { failsLoad = value }
    func setSaveFailure(_ value: Bool) { failsSave = value }
    func load() async throws -> TimetableSnapshot {
        if failsLoad { throw TestFailure.storage }
        return snapshot
    }
    func save(_ snapshot: TimetableSnapshot) async throws {
        if failsSave { throw TestFailure.storage }
        saveCount += 1
        self.snapshot = snapshot
    }
    func clear() async throws {
        clearCount += 1
        snapshot = .empty
    }
}

private actor SuspendedDocumentRead {
    private var continuation: CheckedContinuation<Data, Error>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var readCount = 0

    func read() async throws -> Data {
        readCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(with data: Data) {
        continuation?.resume(returning: data)
        continuation = nil
    }
}
