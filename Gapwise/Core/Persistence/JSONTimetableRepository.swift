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
        guard fileManager.fileExists(atPath: fileURL.path) else { return .empty }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(TimetableSnapshot.self, from: data)
    }

    func save(_ snapshot: TimetableSnapshot) async throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)

        #if os(iOS)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        #endif
    }

    func clear() async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}
