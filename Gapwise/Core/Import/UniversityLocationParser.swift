import Foundation

enum UniversityBuildingCatalog {
    // This is intentionally a small classroom-oriented subset of codes published by UTM.
    // Source: https://www.utm.utoronto.ca/facilities/notices/by-building
    // Campus map: https://www.utm.utoronto.ca/future-students/sites/files/future-students/documents/2025-03/MOH25_CampusMap.pdf
    static let utmBuildingNames: [String: String] = [
        "AX": "Academic Annex",
        "CC": "Communication, Culture, and Technology Building",
        "CCT": "Communication, Culture, and Technology Building",
        "DH": "Deerfield Hall",
        "DV": "William G. Davis Building",
        "DW": "Erindale Studio Theatre",
        "HB": "Terrence Donnelly Health Sciences Complex",
        "HSC": "Terrence Donnelly Health Sciences Complex",
        "HM": "Hazel McCallion Academic Learning Centre",
        "IB": "Instructional Centre",
        "KN": "Kaneff Centre and Innovation Complex",
        "MN": "Maanjiwe nendamowinan",
        "RA": "Recreation, Athletics and Wellness Centre",
        "RAWC": "Recreation, Athletics and Wellness Centre",
        "SB": "Science Building",
        "XR": "Student Centre",
    ]

    static func isKnownUTMCode(_ code: String) -> Bool {
        utmBuildingNames[code.uppercased()] != nil
    }
}

struct UniversityLocationParser: Sendable {
    func parse(_ rawValue: String?) -> MeetingLocation? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.uppercased()
        if containsAny(normalized, values: ["ONLINE", "REMOTE", "VIRTUAL", "ZOOM", "ASYNCHRONOUS"]) {
            return MeetingLocation(displayName: "Online", rawLocation: trimmed, kind: .online)
        }
        if containsAny(normalized, values: ["TBA", "TBD", "TO BE ANNOUNCED", "TO BE DETERMINED"]) {
            return MeetingLocation(displayName: "TBA", rawLocation: trimmed, kind: .toBeAnnounced)
        }

        if let components = buildingAndRoom(in: trimmed) {
            return MeetingLocation(
                displayName: trimmed,
                rawLocation: trimmed,
                buildingCode: components.building,
                room: components.room,
                kind: .physical
            )
        }

        return MeetingLocation(displayName: trimmed, rawLocation: trimmed, kind: .unknown)
    }

    private func containsAny(_ value: String, values: [String]) -> Bool {
        values.contains { value.contains($0) }
    }

    private func buildingAndRoom(in location: String) -> (building: String, room: String)? {
        let rawTokens = location.split(whereSeparator: { $0.isWhitespace || ",;/()-".contains($0) }).map(String.init)

        for (index, rawToken) in rawTokens.enumerated() {
            let letterPrefix = rawToken.prefix(while: \.isLetter)
            let token = letterPrefix.uppercased()
            let suffix = rawToken.dropFirst(letterPrefix.count)

            if (2...4).contains(token.count), suffix.first?.isNumber == true {
                return (token, String(suffix))
            }

            guard
                rawToken == rawToken.uppercased() || UniversityBuildingCatalog.isKnownUTMCode(token),
                (2...4).contains(token.count),
                index + 1 < rawTokens.count
            else {
                continue
            }

            let nextToken = rawTokens[index + 1].trimmingCharacters(in: .punctuationCharacters)
            if nextToken.first?.isNumber == true {
                return (token, nextToken)
            }
        }

        return nil
    }
}
