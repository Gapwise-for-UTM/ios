import Foundation

enum MeetingReviewSeverity: Int, Comparable, Sendable {
    case information
    case needsCorrection

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum MeetingReviewIssueKind: Hashable, Sendable {
    case missingCourseTitle
    case missingLocation
    case unknownCampus
    case unknownMeetingType
    case unrecognizedLocation
}

struct MeetingReviewIssue: Hashable, Identifiable, Sendable {
    var id: MeetingReviewIssueKind { kind }

    let kind: MeetingReviewIssueKind
    let severity: MeetingReviewSeverity
    let message: String
}

struct MeetingReviewItem: Identifiable, Sendable {
    var id: MeetingIdentity { meeting.id }
    var needsCorrection: Bool { issues.contains { $0.severity == .needsCorrection } }

    let meeting: CourseMeeting
    let issues: [MeetingReviewIssue]
}

struct TimetableReviewService: Sendable {
    func items(in meetings: [CourseMeeting]) -> [MeetingReviewItem] {
        meetings.compactMap { meeting in
            let issues = issues(for: meeting)
            guard !issues.isEmpty else { return nil }
            return MeetingReviewItem(meeting: meeting, issues: issues)
        }.sorted { lhs, rhs in
            if lhs.needsCorrection != rhs.needsCorrection { return lhs.needsCorrection }
            if lhs.meeting.courseCode != rhs.meeting.courseCode {
                return lhs.meeting.courseCode < rhs.meeting.courseCode
            }
            if lhs.meeting.startTime != rhs.meeting.startTime {
                return lhs.meeting.startTime < rhs.meeting.startTime
            }
            return lhs.meeting.id < rhs.meeting.id
        }
    }

    func unresolvedCount(in meetings: [CourseMeeting]) -> Int {
        items(in: meetings).lazy.filter(\.needsCorrection).count
    }

    func issues(for meeting: CourseMeeting) -> [MeetingReviewIssue] {
        var issues: [MeetingReviewIssue] = []

        if meeting.campus == .unknown, !meeting.overriddenFields.contains(.campus) {
            issues.append(
                MeetingReviewIssue(
                    kind: .unknownCampus,
                    severity: .needsCorrection,
                    message: "Campus could not be determined."
                ))
        }
        if meeting.meetingType == .other, !meeting.overriddenFields.contains(.meetingType) {
            issues.append(
                MeetingReviewIssue(
                    kind: .unknownMeetingType,
                    severity: .needsCorrection,
                    message: "Confirm this meeting type."
                ))
        }
        if meeting.location == nil, !meeting.overriddenFields.contains(.location) {
            issues.append(
                MeetingReviewIssue(
                    kind: .missingLocation,
                    severity: .information,
                    message: "No location was provided."
                ))
        } else if meeting.location?.kind == .unknown, !meeting.overriddenFields.contains(.location) {
            issues.append(
                MeetingReviewIssue(
                    kind: .unrecognizedLocation,
                    severity: .information,
                    message: "Location was preserved but not recognized."
                ))
        }
        if meeting.courseTitle == nil, !meeting.overriddenFields.contains(.courseTitle) {
            issues.append(
                MeetingReviewIssue(
                    kind: .missingCourseTitle,
                    severity: .information,
                    message: "No course title was provided."
                ))
        }
        // Preserve the explicit field order within each severity.
        return issues.filter { $0.severity == .needsCorrection }
            + issues.filter { $0.severity == .information }
    }
}
