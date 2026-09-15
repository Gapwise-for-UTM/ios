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
                // Coordinate with Files/iCloud providers while the security scope is active.
                var coordinationError: NSError?
                var result: Result<Data, Error>?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { fileURL in
                    result = Result {
                        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                        guard values.isRegularFile == true else { throw ImportedDocumentReadError.notAFile }
                        if let fileSize = values.fileSize, fileSize > maximumByteCount {
                            throw ImportedDocumentReadError.tooLarge(maximumBytes: maximumByteCount)
                        }

                        let handle = try FileHandle(forReadingFrom: fileURL)
                        defer { try? handle.close() }
                        // Read at most the limit plus one byte even if the file grows after metadata was read.
                        var data = Data()
                        while data.count <= maximumByteCount {
                            let chunk = try handle.read(upToCount: min(65_536, maximumByteCount + 1 - data.count))
                            guard let chunk, !chunk.isEmpty else { break }
                            data.append(chunk)
                        }
                        guard data.count <= maximumByteCount else {
                            throw ImportedDocumentReadError.tooLarge(maximumBytes: maximumByteCount)
                        }
                        return data
                    }
                }
                if let coordinationError { throw coordinationError }
                guard let result else { throw ImportedDocumentReadError.unreadable }
                return try result.get()
            } catch let error as ImportedDocumentReadError {
                throw error
            } catch {
                throw ImportedDocumentReadError.unreadable
            }
        }.value
    }
}
