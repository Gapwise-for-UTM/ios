import Foundation

struct TimetableReconciler: Sendable {
    // Only an exact source + UID match is reconciled. A changed UID remains a new meeting,
    // avoiding destructive guesses based on mutable course labels, rooms, or times.
    func plan(
        draft: TimetableImportDraft,
        existingSnapshot: TimetableSnapshot,
        importedAt: Date
    ) throws -> TimetableImportPlan {
        let existingSourceMeetings = existingSnapshot.meetings.filter {
            $0.origin.kind == .calendarImport && $0.origin.sourceIdentifier == draft.sourceIdentifier
        }
        let meetingsFromOtherSources = existingSnapshot.meetings.filter {
            $0.origin.kind != .calendarImport || $0.origin.sourceIdentifier != draft.sourceIdentifier
        }
        let existingByKey = existingSourceMeetings.reduce(into: [ImportedMeetingIdentity: CourseMeeting]()) {
            result, meeting in
            guard let key = ImportedMeetingIdentity(meeting), result[key] == nil else { return }
            result[key] = meeting
        }

        var added = 0
        var updated = 0
        var unchanged = 0
        var suppressed = 0
        var incomingKeys: Set<ImportedMeetingIdentity> = []
        var previewMeetings: [CourseMeeting] = []

        for incoming in draft.meetings {
            guard let key = ImportedMeetingIdentity(incoming) else { continue }
            guard incomingKeys.insert(key).inserted else { continue }

            if existingSnapshot.suppressedImportedMeetings.contains(key) {
                suppressed += 1
                continue
            }

            if let existing = existingByKey[key] {
                let merged = try existing.mergingImportedSource(incoming)
                previewMeetings.append(merged)
                if existing.hasSameImportedSource(as: incoming) {
                    unchanged += 1
                } else {
                    updated += 1
                }
            } else {
                previewMeetings.append(incoming)
                added += 1
            }
        }

        let retainedMeetings = existingSourceMeetings.filter { meeting in
            guard let key = ImportedMeetingIdentity(meeting), !incomingKeys.contains(key) else { return false }
            return !draft.allowsMissingEventRemoval || draft.retainedEventUIDs.contains(key.eventUID)
        }
        let retainedKeys = Set(retainedMeetings.compactMap(ImportedMeetingIdentity.init))
        let removedFromSource = existingByKey.keys.lazy.filter {
            !incomingKeys.contains($0) && !retainedKeys.contains($0)
        }.count
        let sources = upsertingSource(
            TimetableSource(
                id: draft.sourceIdentifier,
                kind: .calendarFile,
                displayName: draft.sourceName,
                lastImportedAt: importedAt
            ),
            into: existingSnapshot.sources
        )
        let resultingMeetings = meetingsFromOtherSources + previewMeetings + retainedMeetings
        let unresolved = TimetableReviewService().unresolvedCount(in: previewMeetings)

        return TimetableImportPlan(
            draft: draft,
            changes: TimetableImportChanges(
                added: added,
                updated: updated,
                unchanged: unchanged,
                removedFromSource: removedFromSource,
                suppressed: suppressed,
                unresolved: unresolved,
                retainedForReview: retainedMeetings.count
            ),
            previewMeetings: previewMeetings,
            resultingSnapshot: TimetableSnapshot(
                meetings: resultingMeetings,
                sources: sources,
                suppressedImportedMeetings: existingSnapshot.suppressedImportedMeetings,
                lastModified: importedAt
            )
        )
    }

    private func upsertingSource(_ source: TimetableSource, into sources: [TimetableSource]) -> [TimetableSource] {
        var updated = sources.filter { $0.id != source.id }
        updated.append(source)
        return updated.sorted { lhs, rhs in
            if lhs.lastImportedAt != rhs.lastImportedAt { return lhs.lastImportedAt > rhs.lastImportedAt }
            if lhs.displayName != rhs.displayName { return lhs.displayName < rhs.displayName }
            return lhs.id < rhs.id
        }
    }
}
