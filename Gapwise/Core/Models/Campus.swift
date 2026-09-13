import Foundation

enum Campus: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case utm
    case utsg
    case utsc
    case unknown

    var id: Self { self }

    static let selectableCases: [Self] = [.utm, .utsg, .utsc]

    var shortName: String {
        switch self {
        case .utm: "UTM"
        case .utsg: "UTSG"
        case .utsc: "UTSC"
        case .unknown: "Unknown"
        }
    }

    var fullName: String {
        switch self {
        case .utm: "University of Toronto Mississauga"
        case .utsg: "University of Toronto St. George"
        case .utsc: "University of Toronto Scarborough"
        case .unknown: "Campus not determined"
        }
    }
}
