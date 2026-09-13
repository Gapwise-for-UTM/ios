import Foundation

struct TimetableReconciler: Sendable {
    func plan(
        draft: TimetableImportDraft,
        existingSnapshot: TimetableSnapshot,
        importedAt: Date
    ) -> TimetableImportPlan {
        var meetings = existingSnapshot.meetings
        var indexesByKey: [ImportedMeetingKey: Int] = [:]

        for (index, meeting) in meetings.enumerated() {
            guard let key = ImportedMeetingKey(meeting) else { continue }
            if indexesByKey[key] == nil {
                indexesByKey[key] = index
            }
        }

        var added = 0
        var updated = 0
        var unchanged = 0
        var incomingKeys: Set<ImportedMeetingKey> = []

        for meeting in draft.meetings {
            guard let key = ImportedMeetingKey(meeting) else { continue }
            incomingKeys.insert(key)

            if let existingIndex = indexesByKey[key] {
                if meetings[existingIndex] == meeting {
                    unchanged += 1
                } else {
                    meetings[existingIndex] = meeting
                    updated += 1
                }
            } else {
                indexesByKey[key] = meetings.count
                meetings.append(meeting)
                added += 1
            }
        }

        let retained = meetings.lazy.filter { meeting in
            guard
                meeting.origin.kind == .calendarImport,
                meeting.origin.sourceIdentifier == draft.sourceIdentifier,
                let key = ImportedMeetingKey(meeting)
            else {
                return false
            }
            return !incomingKeys.contains(key)
        }.count

        return TimetableImportPlan(
            draft: draft,
            changes: TimetableImportChanges(
                added: added,
                updated: updated,
                unchanged: unchanged,
                retainedFromPreviousImport: retained
            ),
            resultingSnapshot: TimetableSnapshot(meetings: meetings, lastModified: importedAt)
        )
    }
}

private struct ImportedMeetingKey: Hashable {
    let importSourceIdentifier: String
    let eventUID: String

    init?(_ meeting: CourseMeeting) {
        guard
            meeting.origin.kind == .calendarImport,
            let sourceIdentifier = meeting.origin.sourceIdentifier
        else {
            return nil
        }
        importSourceIdentifier = sourceIdentifier
        eventUID = meeting.id.sourceIdentifier
    }
}
