import Foundation

enum ImportedDocumentReadError: Error, LocalizedError, Sendable {
    case notAFile
    case tooLarge(maximumBytes: Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notAFile:
            "The selected item is not a calendar file."
        case let .tooLarge(maximumBytes):
            "The selected file is larger than the \(maximumBytes / 1_048_576) MB import limit."
        case .unreadable:
            "The selected calendar could not be read."
        }
    }
}

enum ImportedDocumentReader {
    static func read(url: URL, maximumByteCount: Int) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let accessedSecurityScopedResource = url.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScopedResource {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if values.isRegularFile == false {
                    throw ImportedDocumentReadError.notAFile
                }
                if let fileSize = values.fileSize, fileSize > maximumByteCount {
                    throw ImportedDocumentReadError.tooLarge(maximumBytes: maximumByteCount)
                }

                let data = try Data(contentsOf: url)
                guard data.count <= maximumByteCount else {
                    throw ImportedDocumentReadError.tooLarge(maximumBytes: maximumByteCount)
                }
                return data
            } catch let error as ImportedDocumentReadError {
                throw error
            } catch {
                throw ImportedDocumentReadError.unreadable
            }
        }.value
    }
}
