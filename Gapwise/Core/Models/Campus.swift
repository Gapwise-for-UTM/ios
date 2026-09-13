import Foundation

enum Campus: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case utm
    case utsg
    case utsc

    var id: Self { self }

    var shortName: String {
        switch self {
        case .utm: "UTM"
        case .utsg: "UTSG"
        case .utsc: "UTSC"
        }
    }

    var fullName: String {
        switch self {
        case .utm: "University of Toronto Mississauga"
        case .utsg: "University of Toronto St. George"
        case .utsc: "University of Toronto Scarborough"
        }
    }
}
