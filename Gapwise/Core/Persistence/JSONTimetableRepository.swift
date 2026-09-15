import Foundation

actor JSONTimetableRepository: TimetableRepository {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    static func applicationSupport(fileManager: FileManager = .default) throws -> Self {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw TimetableRepositoryError.applicationSupportUnavailable
        }

        return Self(
            fileURL:
                baseURL
                .appendingPathComponent("Gapwise", isDirectory: true)
                .appendingPathComponent("timetable.json"),
            fileManager: fileManager
        )
    }

    func load() async throws -> TimetableSnapshot {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(TimetableSnapshot.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return .empty
        }
    }

    func save(_ snapshot: TimetableSnapshot) async throws {
        let data = try encoder.encode(snapshot)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        #if os(iOS)
            try data.write(
                to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        #else
            try data.write(to: fileURL, options: .atomic)
        #endif
    }

    func clear() async throws {
        do {
            try fileManager.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }
}
