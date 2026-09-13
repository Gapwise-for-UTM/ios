import Foundation

struct TimetableSnapshot: Codable, Equatable, Sendable {
    static let empty = TimetableSnapshot(meetings: [], lastModified: nil)

    var meetings: [CourseMeeting]
    var lastModified: Date?

    init(meetings: [CourseMeeting], lastModified: Date? = nil) {
        self.meetings = meetings
        self.lastModified = lastModified
    }
}

enum AppearancePreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

struct UserPreferences: Codable, Equatable, Sendable {
    var appearance: AppearancePreference
    var campusContext: Campus

    static let defaults = UserPreferences(appearance: .system, campusContext: .utm)
}
