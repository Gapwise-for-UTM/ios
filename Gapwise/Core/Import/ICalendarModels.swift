import Foundation

struct ICalendarDateTime: Equatable, Sendable {
    let instant: Date
    let timeZoneIdentifier: String?
    let isFloating: Bool
}

enum ICalendarTemporalValue: Equatable, Sendable {
    case dateTime(ICalendarDateTime)
    case date(LocalDate)
}

enum ICalendarEventIssue: Error, Equatable, Sendable {
    case duplicateProperty(String)
    case invalidDate(String)
    case malformedProperty(String?)
    case unknownTimeZone(String)
}

struct ICalendarEvent: Equatable, Sendable {
    let uid: String?
    let summary: String?
    let location: String?
    let description: String?
    let start: ICalendarTemporalValue?
    let end: ICalendarTemporalValue?
    let recurrenceRule: String?
    let unsupportedRecurrenceProperties: Set<String>
    let status: String?
    let issues: [ICalendarEventIssue]
}

struct ICalendarDocument: Equatable, Sendable {
    let calendarName: String?
    let productIdentifier: String?
    let events: [ICalendarEvent]
}
