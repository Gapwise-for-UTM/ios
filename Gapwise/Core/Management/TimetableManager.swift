import Foundation

enum TimetableManagementError: Error, Equatable, LocalizedError {
    case meetingNotFound
    case courseNotFound
    case sourceNotFound

    var errorDescription: String? {
        switch self {
        case .meetingNotFound: "That meeting is no longer in your timetable."
        case .courseNotFound: "That course is no longer in your timetable."
        case .sourceNotFound: "That import source is no longer available."
        }
    }
}

struct TimetableManager: Sendable {
    func updateMeeting(
        id: MeetingIdentity,
        with edit: CourseMeetingEdit,
        in snapshot: TimetableSnapshot,
        modifiedAt: Date
    ) throws -> TimetableSnapshot {
        try replacingMeeting(id: id, in: snapshot, modifiedAt: modifiedAt) { meeting in
            try meeting.applying(edit)
        }
    }

    func overrideCampus(
        id: MeetingIdentity,
        campus: Campus,
        in snapshot: TimetableSnapshot,
        modifiedAt: Date
    ) throws -> TimetableSnapshot {
        try replacingMeeting(id: id, in: snapshot, modifiedAt: modifiedAt) { meeting in
            try meeting.overridingCampus(campus)
        }
    }

    func acknowledgeMeetingType(
        id: MeetingIdentity,
        in snapshot: TimetableSnapshot,
        modifiedAt: Date
    ) throws -> TimetableSnapshot {
        try replacingMeeting(id: id, in: snapshot, modifiedAt: modifiedAt) { meeting in
            try meeting.acknowledgingMeetingType()
        }
    }

    func removeMeeting(
        id: MeetingIdentity,
        from snapshot: TimetableSnapshot,
        modifiedAt: Date
    ) throws -> TimetableSnapshot {
        guard let meeting = snapshot.meetings.first(where: { $0.id == id }) else {
            throw TimetableManagementError.meetingNotFound
        }
        return removing(meetings: [meeting], from: snapshot, modifiedAt: modifiedAt)
    }

    func removeCourse(
        _ course: CourseIdentity,
        from snapshot: TimetableSnapshot,
        modifiedAt: Date
    ) throws -> TimetableSnapshot {
        let matchingMeetings = snapshot.meetings.filter { CourseIdentity($0) == course }
        guard !matchingMeetings.isEmpty else { throw TimetableManagementError.courseNotFound }
        return removing(meetings: matchingMeetings, from: snapshot, modifiedAt: modifiedAt)
    }

    func removeSource(
        id: String,
        from snapshot: TimetableSnapshot,
        modifiedAt: Date
    ) throws -> TimetableSnapshot {
        let hasSource = snapshot.sources.contains { $0.id == id }
            || snapshot.meetings.contains { $0.origin.sourceIdentifier == id }
        guard hasSource else { throw TimetableManagementError.sourceNotFound }

        return TimetableSnapshot(
            meetings: snapshot.meetings.filter { $0.origin.sourceIdentifier != id },
            sources: snapshot.sources.filter { $0.id != id },
            suppressedImportedMeetings: snapshot.suppressedImportedMeetings.filter {
                $0.sourceIdentifier != id
            },
            lastModified: modifiedAt
        )
    }

    private func replacingMeeting(
        id: MeetingIdentity,
        in snapshot: TimetableSnapshot,
        modifiedAt: Date,
        transform: (CourseMeeting) throws -> CourseMeeting
    ) throws -> TimetableSnapshot {
        guard let index = snapshot.meetings.firstIndex(where: { $0.id == id }) else {
            throw TimetableManagementError.meetingNotFound
        }
        var updated = snapshot
        let replacement = try transform(updated.meetings[index])
        guard replacement != updated.meetings[index] else { return snapshot }
        updated.meetings[index] = replacement
        updated.lastModified = modifiedAt
        return updated
    }

    private func removing(
        meetings removedMeetings: [CourseMeeting],
        from snapshot: TimetableSnapshot,
        modifiedAt: Date
    ) -> TimetableSnapshot {
        let removedIDs = Set(removedMeetings.map(\.id))
        let suppressions = Set(removedMeetings.compactMap(ImportedMeetingIdentity.init))
        var updated = snapshot
        updated.meetings.removeAll { removedIDs.contains($0.id) }
        updated.suppressedImportedMeetings.formUnion(suppressions)
        updated.lastModified = modifiedAt
        return updated
    }
}
