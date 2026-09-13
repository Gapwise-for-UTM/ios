import Foundation

#if DEBUG
    enum PreviewData {
        static let calendar = Calendar.gapwiseToronto

        static var timetable: TimetableSnapshot {
            TimetableSnapshot(meetings: meetings, lastModified: .now)
        }

        @MainActor
        static func appModel(selectedDate: Date = .now) -> AppModel {
            AppModel(
                timetableRepository: InMemoryTimetableRepository(snapshot: timetable),
                preferencesRepository: InMemoryPreferencesRepository(),
                timetable: timetable,
                selectedTimetableDate: selectedDate
            )
        }

        private static var meetings: [CourseMeeting] {
            let year = calendar.component(.year, from: .now)
            let term = AcademicTerm(
                id: .init(rawValue: "preview-term"),
                displayName: "Preview Term",
                startsOn: LocalDate(year: year - 1, month: 1, day: 1),
                endsOn: LocalDate(year: year + 1, month: 12, day: 31)
            )

            return [
                meeting(
                    campus: .utm,
                    code: "DEMO101",
                    title: "Sample Seminar",
                    term: term,
                    courseSection: "F",
                    type: .lecture,
                    section: "LEC0101",
                    days: [.monday, .wednesday, .friday],
                    start: (10, 0),
                    end: (11, 0),
                    location: "Sample Room A",
                    sourceID: "preview-utm-demo101-lec0101"
                ),
                meeting(
                    campus: .utsg,
                    code: "DEMO204",
                    title: "Sample Studio",
                    term: term,
                    courseSection: "F",
                    type: .practical,
                    section: "PRA0201",
                    days: [.tuesday, .thursday],
                    start: (13, 0),
                    end: (15, 0),
                    location: "Sample Lab B",
                    sourceID: "preview-utsg-demo204-pra0201"
                ),
                meeting(
                    campus: .utm,
                    code: "DEMO310",
                    title: "Sample Tutorial",
                    term: term,
                    courseSection: "F",
                    type: .tutorial,
                    section: "TUT0102",
                    days: [.monday],
                    start: (11, 0),
                    end: (12, 0),
                    location: "Sample Room C",
                    sourceID: "preview-utm-demo310-tut0102"
                ),
            ].compactMap { $0 }
        }

        private static func meeting(
            campus: Campus,
            code: String,
            title: String,
            term: AcademicTerm,
            courseSection: String,
            type: MeetingType,
            section: String,
            days: Set<Weekday>,
            start: (Int, Int),
            end: (Int, Int),
            location: String,
            sourceID: String
        ) -> CourseMeeting? {
            guard
                let courseCode = CourseCode(rawValue: code),
                let startTime = LocalTime(hour: start.0, minute: start.1),
                let endTime = LocalTime(hour: end.0, minute: end.1)
            else {
                return nil
            }

            return try? CourseMeeting(
                campus: campus,
                courseCode: courseCode,
                courseTitle: title,
                term: term,
                courseSection: courseSection,
                meetingType: type,
                meetingSection: section,
                days: days,
                startTime: startTime,
                endTime: endTime,
                location: MeetingLocation(displayName: location),
                sourceIdentifier: sourceID
            )
        }
    }
#endif
