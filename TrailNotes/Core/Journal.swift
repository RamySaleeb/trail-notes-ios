import Foundation

public struct JournalEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var place: String
    public var notes: String
    public var isFavorite: Bool
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, place: String, notes: String,
                isFavorite: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.place = place
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    public static let samples: [JournalEntry] = [
        .init(title: "A quieter way home", place: "River path",
              notes: "A fictional sample: late afternoon light, a gentle breeze, and a new path worth remembering.", isFavorite: true),
        .init(title: "Above the morning mist", place: "North ridge",
              notes: "A fictional sample: an easy climb with a wide view. Bring a notebook next time.")
    ]
}

public enum JournalQuery {
    public static func filter(_ entries: [JournalEntry], text: String, favoritesOnly: Bool) -> [JournalEntry] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            (!favoritesOnly || entry.isFavorite) && (query.isEmpty ||
                [entry.title, entry.place, entry.notes].contains { $0.localizedStandardContains(query) })
        }.sorted { $0.createdAt > $1.createdAt }
    }
}

/// Serialized disk access. Missing data is a first launch; corrupt data is an error.
public actor JournalRepository {
    private let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> [JournalEntry]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode([JournalEntry].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ entries: [JournalEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
