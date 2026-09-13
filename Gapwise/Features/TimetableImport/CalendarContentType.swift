import UniformTypeIdentifiers

extension UTType {
    static let gapwiseICalendar = UTType(filenameExtension: "ics", conformingTo: .calendarEvent) ?? .calendarEvent
}
