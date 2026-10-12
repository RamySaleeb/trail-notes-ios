import Foundation
import Testing
@testable import TrailNotesCore

@Test func searchesNotesAndTrimsWhitespace() {
    let entry = JournalEntry(title: "Walk", place: "Park", notes: "Quiet WATERFALL")
    #expect(JournalQuery.filter([entry], text: " waterfall ", favoritesOnly: false) == [entry])
    #expect(JournalQuery.filter([entry], text: "missing", favoritesOnly: false).isEmpty)
}

@Test func combinesFavoritesWithSearchAndSortsNewestFirst() {
    let old = JournalEntry(title: "Ridge", place: "North", notes: "", isFavorite: true, createdAt: .distantPast)
    let new = JournalEntry(title: "Ridge", place: "South", notes: "", isFavorite: true)
    let other = JournalEntry(title: "Ridge", place: "West", notes: "")
    #expect(JournalQuery.filter([old, other, new], text: "ridge", favoritesOnly: true) == [new, old])
}

@Test func persistsEntriesAndDistinguishesEmptyFromFirstLaunch() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = JournalRepository(fileURL: directory.appendingPathComponent("journal.json"))
    #expect(try await repository.load() == nil)
    let entries = [JournalEntry(title: "Saved", place: "Here", notes: "Original notes")]
    try await repository.save(entries)
    #expect(try await repository.load() == entries)
    try await repository.save([])
    #expect(try await repository.load() == [])
}

@Test func corruptDataIsNotSilentlyReplaced() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    try Data("invalid json".utf8).write(to: file)
    let repository = JournalRepository(fileURL: file)
    await #expect(throws: (any Error).self) { try await repository.load() }
    #expect(try String(contentsOf: file, encoding: .utf8) == "invalid json")
}
