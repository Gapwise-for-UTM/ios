import Foundation

struct TimetableImportService: Sendable {
    static let maximumDocumentSize = ICalendarParser.maximumByteCount

    func prepareImport(
        data: Data,
        suggestedFileName: String?,
        existingSnapshot: TimetableSnapshot,
        importedAt: Date = .now
    ) throws -> TimetableImportPlan {
        let document = try ICalendarParser().parse(data)
        let draft = try TimetableImporter().interpret(document, suggestedFileName: suggestedFileName)
        return TimetableReconciler().plan(draft: draft, existingSnapshot: existingSnapshot, importedAt: importedAt)
    }
}
