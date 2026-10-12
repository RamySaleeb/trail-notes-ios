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

// Fixed identifiers and distinct timestamps make ordering and equality repeatable.
private let searchEntries = [
    JournalEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                 title: "Sunrise", place: "Cliff", notes: "Golden sky",
                 isFavorite: true, createdAt: Date(timeIntervalSince1970: 100)),
    JournalEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                 title: "Evening", place: "Harbor", notes: "Quiet boats",
                 createdAt: Date(timeIntervalSince1970: 300)),
    JournalEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                 title: "Forest", place: "Valley", notes: "A waterfall nearby",
                 isFavorite: true, createdAt: Date(timeIntervalSince1970: 200))
]

@Test(arguments: ["", " \t\r\n ", "\u{00A0}\u{2003}\n"])
func blankSearchKeepsEntriesAndAppliesFavorites(query: String) {
    #expect(JournalQuery.filter(searchEntries, text: query, favoritesOnly: false)
            == [searchEntries[1], searchEntries[2], searchEntries[0]])
    #expect(JournalQuery.filter(searchEntries, text: query, favoritesOnly: true)
            == [searchEntries[2], searchEntries[0]])
    #expect(JournalQuery.filter([], text: query, favoritesOnly: false).isEmpty)
}

@Test(arguments: [("Sunrise", 0), ("Harbor", 1), ("waterfall", 2)])
func searchesEachFieldAndTrimsQuery(query: String, index: Int) {
    // Each term exists in exactly one field of exactly one entry.
    #expect(JournalQuery.filter(searchEntries, text: " \t\(query)\n ", favoritesOnly: false)
            == [searchEntries[index]])
}

@Test func favoritesRequireTheSearchToMatchToo() {
    #expect(JournalQuery.filter(searchEntries, text: "missing", favoritesOnly: true).isEmpty)
    // A text match in a nonfavorite must not leak through the favorites filter.
    #expect(JournalQuery.filter(searchEntries, text: "Harbor", favoritesOnly: true).isEmpty)
    #expect(JournalQuery.filter(searchEntries, text: "waterfall", favoritesOnly: true)
            == [searchEntries[2]])
    #expect(JournalQuery.filter([], text: "waterfall", favoritesOnly: true).isEmpty)
}

@Test(arguments: [("Caf\u{00E9}", "Cafe\u{0301}"), ("Cafe\u{0301}", "Caf\u{00E9}"), ("東京散歩", "東京")])
func unicodeSearchUsesCanonicalEquivalenceAndExactText(title: String, query: String) {
    // localizedStandardContains uses the current locale. Canonically equivalent
    // é spellings and an exact Japanese substring avoid locale-specific case
    // mappings (for example Turkish I) and collation/order assumptions. This
    // deliberately does not promise identical accent folding for every locale.
    let entry = JournalEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                             title: title, place: "", notes: "",
                             createdAt: Date(timeIntervalSince1970: 400))
    #expect(JournalQuery.filter([entry], text: query, favoritesOnly: false) == [entry])
    #expect(JournalQuery.filter([entry], text: "不存在", favoritesOnly: false).isEmpty)
}

@Test func searchDoesNotMutateInputOrderOrEntryValues() {
    let input = searchEntries
    let original = input
    for query in ["", " \n ", "waterfall", "missing"] {
        for favoritesOnly in [false, true] {
            var result = JournalQuery.filter(input, text: query, favoritesOnly: favoritesOnly)
            #expect(input == original) // Includes every field and original order.
            if !result.isEmpty {
                result[0].title = "Changed result copy"
                result[0].place = "Changed place"
                result[0].notes = "Changed notes"
                result[0].isFavorite.toggle()
            }
            result.reverse()
            #expect(input == original)
        }
    }
}
