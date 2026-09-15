import Foundation

enum CampusDetectionEvidence: Equatable, Sendable {
    case courseCodeSuffix
    case buildingCode(String)
    case calendarMetadata
    case conflictingSignals
    case importContext
    case locationWording
    case unresolved
}

struct CampusDetection: Equatable, Sendable {
    let campus: Campus
    let evidence: CampusDetectionEvidence
}

struct CampusDetector: Sendable {
    func detect(
        calendarName: String?,
        productIdentifier: String?,
        location: MeetingLocation?,
        description: String?,
        importContext: Campus? = nil,
        courseCode: CourseCode? = nil
    ) -> CampusDetection {
        // Gapwise core timetable-types.ts owns this U of T course-code convention.
        // A UTM import preference cannot relabel a known non-UTM course.
        if let suffix = courseCode?.rawValue.last {
            let campus: Campus?
            switch suffix {
            case "5": campus = .utm
            case "1": campus = .utsg
            case "3": campus = .utsc
            default: campus = nil
            }
            if let campus { return CampusDetection(campus: campus, evidence: .courseCodeSuffix) }
            return CampusDetection(campus: .unknown, evidence: .unresolved)
        }
        if let importContext, importContext != .unknown {
            return CampusDetection(campus: importContext, evidence: .importContext)
        }

        let metadataCandidates = candidates(
            in: [calendarName, productIdentifier].compactMap { $0 }.joined(separator: " "))
        let eventCandidates = candidates(
            in: [location?.rawLocation, description].compactMap { $0 }.joined(separator: " ")
        )
        let explicitCandidates = metadataCandidates.union(eventCandidates)

        if explicitCandidates.count > 1 {
            return CampusDetection(campus: .unknown, evidence: .conflictingSignals)
        }
        if let campus = explicitCandidates.first {
            let evidence: CampusDetectionEvidence =
                eventCandidates.contains(campus) ? .locationWording : .calendarMetadata
            return CampusDetection(campus: campus, evidence: evidence)
        }

        if let code = location?.buildingCode, UniversityBuildingCatalog.isKnownUTMCode(code) {
            return CampusDetection(campus: .utm, evidence: .buildingCode(code.uppercased()))
        }

        return CampusDetection(campus: .unknown, evidence: .unresolved)
    }

    private func candidates(in value: String) -> Set<Campus> {
        let normalized = value.uppercased()
        let tokens = Set(normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        var matches: Set<Campus> = []

        if tokens.contains("UTM") || normalized.contains("UNIVERSITY OF TORONTO MISSISSAUGA")
            || normalized.contains("MISSISSAUGA CAMPUS")
        {
            matches.insert(.utm)
        }
        if tokens.contains("UTSG") || normalized.contains("ST. GEORGE") || normalized.contains("ST GEORGE") {
            matches.insert(.utsg)
        }
        if tokens.contains("UTSC") || normalized.contains("UNIVERSITY OF TORONTO SCARBOROUGH")
            || normalized.contains("SCARBOROUGH CAMPUS")
        {
            matches.insert(.utsc)
        }
        return matches
    }
}
