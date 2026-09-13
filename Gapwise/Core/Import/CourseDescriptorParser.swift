import Foundation

struct ParsedCourseDescriptor: Equatable, Sendable {
    let courseCode: CourseCode
    let courseTitle: String?
    let meetingType: MeetingType
    let meetingSection: String
    let rawMeetingType: String
    let instructor: String?
}

struct CourseDescriptorParser: Sendable {
    private static let courseCodePattern =
        #"(?i)(?<![A-Z0-9])([A-Z]{2,4}(?:[0-9]{3}|[A-Z][0-9]{2})[A-Z][0-9])(?![A-Z0-9])"#
    private static let meetingPattern = #"(?i)(?<![A-Z0-9])([A-Z]{3})[\s\-:]?([0-9]{3,5})(?![A-Z0-9])"#

    func parse(summary: String?, description: String?) -> ParsedCourseDescriptor? {
        let fields = [summary, description].compactMap { $0 }
        for field in fields {
            guard
                let courseMatch = firstMatch(pattern: Self.courseCodePattern, in: [field]),
                let rawCourseCode = courseMatch.groups.first,
                let courseCode = CourseCode(rawValue: rawCourseCode),
                let meetingMatch = firstMatch(pattern: Self.meetingPattern, in: [field]),
                let capturedMeetingType = meetingMatch.groups.first,
                let capturedSection = meetingMatch.groups.dropFirst().first
            else {
                continue
            }

            let rawMeetingType = capturedMeetingType.uppercased()
            let sectionDigits = capturedSection.uppercased()
            let meetingType: MeetingType
            switch rawMeetingType {
            case "LEC": meetingType = .lecture
            case "TUT": meetingType = .tutorial
            case "PRA", "LAB": meetingType = .practical
            default: meetingType = .other
            }

            return ParsedCourseDescriptor(
                courseCode: courseCode,
                courseTitle: courseTitle(from: summary, courseCode: courseCode, meetingSection: meetingMatch.fullMatch),
                meetingType: meetingType,
                meetingSection: rawMeetingType + sectionDigits,
                rawMeetingType: rawMeetingType,
                instructor: instructor(from: description)
            )
        }
        return nil
    }

    func containsCourseCode(summary: String?, description: String?) -> Bool {
        firstMatch(
            pattern: Self.courseCodePattern,
            in: [summary, description].compactMap { $0 }
        ) != nil
    }

    private func courseTitle(from summary: String?, courseCode: CourseCode, meetingSection: String) -> String? {
        guard let summary else { return nil }
        let separators = [" - ", " – ", " — "]
        guard let separator = separators.first(where: summary.contains) else { return nil }
        guard let range = summary.range(of: separator) else { return nil }

        var candidate = String(summary[range.upperBound...])
        candidate = candidate.replacingOccurrences(of: courseCode.rawValue, with: "", options: .caseInsensitive)
        candidate = candidate.replacingOccurrences(of: meetingSection, with: "", options: .caseInsensitive)
        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return candidate.isEmpty ? nil : candidate
    }

    private func instructor(from description: String?) -> String? {
        guard let description else { return nil }
        guard
            let match = firstMatch(pattern: #"(?im)^\s*INSTRUCTORS?\s*:\s*(.+)$"#, in: [description]),
            let value = match.groups.first?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

    private func firstMatch(pattern: String, in values: [String]) -> RegexMatch? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }

        for value in values {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            guard let match = expression.firstMatch(in: value, range: range) else { continue }

            var groups: [String] = []
            for groupIndex in 1..<match.numberOfRanges {
                let groupRange = match.range(at: groupIndex)
                guard groupRange.location != NSNotFound, let range = Range(groupRange, in: value) else {
                    return nil
                }
                groups.append(String(value[range]))
            }
            guard let fullRange = Range(match.range(at: 0), in: value) else { continue }
            return RegexMatch(fullMatch: String(value[fullRange]), groups: groups)
        }
        return nil
    }
}

private struct RegexMatch {
    let fullMatch: String
    let groups: [String]
}
