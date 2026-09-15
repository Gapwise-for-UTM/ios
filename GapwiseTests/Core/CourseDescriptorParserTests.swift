import XCTest

#if canImport(Gapwise)
    @testable import Gapwise
#else
    @testable import GapwiseCore
#endif

final class CourseDescriptorParserTests: XCTestCase, @unchecked Sendable {
    func testParsesCommonCourseAndMeetingVariants() throws {
        let cases: [(String, String, MeetingType, String)] = [
            ("MAT157Y5 LEC0101 - Analysis I", "MAT157Y5", .lecture, "LEC0101"),
            ("CSC110Y1 TUT 0201", "CSC110Y1", .tutorial, "TUT0201"),
            ("CSC110Y5 PRA-0301", "CSC110Y5", .practical, "PRA0301"),
            ("PSYA01H3 LAB:0102", "PSYA01H3", .practical, "LAB0102"),
        ]

        for (summary, expectedCode, expectedType, expectedSection) in cases {
            let parsed = try XCTUnwrap(CourseDescriptorParser().parse(summary: summary, description: nil))
            XCTAssertEqual(parsed.courseCode.rawValue, expectedCode)
            XCTAssertEqual(parsed.meetingType, expectedType)
            XCTAssertEqual(parsed.meetingSection, expectedSection)
        }
    }

    func testUnknownMeetingTypeIsPreservedAsOther() throws {
        let parsed = try XCTUnwrap(
            CourseDescriptorParser().parse(summary: "MGT120H5 SEM0401 - Management", description: nil)
        )

        XCTAssertEqual(parsed.meetingType, .other)
        XCTAssertEqual(parsed.rawMeetingType, "SEM")
        XCTAssertEqual(parsed.meetingSection, "SEM0401")
    }

    func testDoesNotCombineUnrelatedCodesAndSectionsAcrossFields() {
        let parser = CourseDescriptorParser()
        let parsed = parser.parse(
            summary: "MAT157Y5 study group",
            description: "Meet near CSC108H5 LEC0101 after class"
        )

        XCTAssertEqual(parsed?.courseCode.rawValue, "CSC108H5")
        XCTAssertNil(parser.parse(summary: "MAT157Y5 study group", description: "Meet near LEC0101 after class"))
    }

    func testCourseWithoutMeetingSectionIsNotAValidDescriptor() {
        let parser = CourseDescriptorParser()

        XCTAssertNil(parser.parse(summary: "MAT157Y5 - Analysis I", description: "Instructor: Test Person"))
        XCTAssertTrue(parser.containsCourseCode(summary: "MAT157Y5 - Analysis I", description: nil))
    }
}
