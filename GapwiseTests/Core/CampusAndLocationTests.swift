import Foundation
import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class CampusAndLocationTests: XCTestCase, @unchecked Sendable {
    func testRecognizesSupportedLocationKinds() {
        let parser = UniversityLocationParser()

        XCTAssertEqual(parser.parse("MN1210")?.kind, .physical)
        XCTAssertEqual(parser.parse("MN1210")?.buildingCode, "MN")
        XCTAssertEqual(parser.parse("MN1210")?.room, "1210")
        XCTAssertEqual(parser.parse("online synchronous")?.kind, .online)
        XCTAssertEqual(parser.parse("Room TBA")?.kind, .toBeAnnounced)
        XCTAssertEqual(parser.parse("Location pending")?.kind, .unknown)
        XCTAssertNil(parser.parse("  "))
    }

    func testLocationCodesUseCanonicalRecognitionWithoutGuessingUnknownIdentity() {
        let parser = UniversityLocationParser()
        XCTAssertEqual(parser.parse("CC 1080")?.buildingCode, "CCT")
        XCTAssertEqual(parser.parse("SB 101")?.buildingCode, "NSB")
        XCTAssertNil(parser.parse("HSC 101")?.buildingCode)
        XCTAssertNil(parser.parse("XY 101")?.buildingCode)
        XCTAssertEqual(parser.parse("XY 101")?.rawLocation, "XY 101")
        XCTAssertEqual(parser.parse("ZZ TBA")?.kind, .toBeAnnounced)
        XCTAssertEqual(parser.parse("N/A")?.kind, .toBeAnnounced)
        XCTAssertEqual(UniversityBuildingCatalog.utmBuildingNames["KN"], "Kaneff Centre")
        XCTAssertEqual(UniversityBuildingCatalog.utmBuildingNames["IC"], "Innovation Complex")
    }

    func testCourseCampusSuffixCannotBeOverriddenByUTMImportContext() {
        let detection = CampusDetector().detect(calendarName: "UTM", productIdentifier: nil,
            location: nil, description: nil, importContext: .utm, courseCode: CourseCode(rawValue: "MAT157Y1"))
        XCTAssertEqual(detection, CampusDetection(campus: .utsg, evidence: .courseCodeSuffix))
    }

    func testKnownUTMBuildingCodesProvideExplainableCampusEvidence() throws {
        let location = try XCTUnwrap(UniversityLocationParser().parse("DV 2072"))
        let detection = CampusDetector().detect(
            calendarName: nil,
            productIdentifier: nil,
            location: location,
            description: nil
        )

        XCTAssertEqual(detection, CampusDetection(campus: .utm, evidence: .buildingCode("DV")))
    }

    func testMetadataAndExplicitLocationWordingDetectAllCampuses() {
        let detector = CampusDetector()

        XCTAssertEqual(
            detector.detect(
                calendarName: "University of Toronto Mississauga",
                productIdentifier: nil,
                location: nil,
                description: nil
            ).campus,
            .utm
        )
        XCTAssertEqual(
            detector.detect(
                calendarName: "St. George timetable",
                productIdentifier: nil,
                location: nil,
                description: nil
            ).campus,
            .utsg
        )
        XCTAssertEqual(
            detector.detect(
                calendarName: nil,
                productIdentifier: nil,
                location: nil,
                description: "University of Toronto Scarborough"
            ).campus,
            .utsc
        )
    }

    func testConflictingAndInsufficientSignalsStayUnknown() {
        let detector = CampusDetector()
        let conflict = detector.detect(
            calendarName: "UTM timetable",
            productIdentifier: nil,
            location: MeetingLocation(displayName: "UTSG", rawLocation: "UTSG"),
            description: nil
        )
        let unresolved = detector.detect(
            calendarName: "Student timetable",
            productIdentifier: nil,
            location: MeetingLocation(displayName: "Room pending"),
            description: nil
        )

        XCTAssertEqual(conflict, CampusDetection(campus: .unknown, evidence: .conflictingSignals))
        XCTAssertEqual(unresolved, CampusDetection(campus: .unknown, evidence: .unresolved))
    }

    func testExplicitImportContextTakesPrecedence() {
        let detection = CampusDetector().detect(
            calendarName: nil,
            productIdentifier: nil,
            location: nil,
            description: nil,
            importContext: .utsc
        )

        XCTAssertEqual(detection, CampusDetection(campus: .utsc, evidence: .importContext))
    }
}
