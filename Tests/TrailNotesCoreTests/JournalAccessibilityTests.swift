import Foundation
import Testing
@testable import TrailNotesCore

@Test func rowAnnouncesFavoriteAndMissingLocation() {
    let entry = JournalEntry(title: "Morning walk", place: " \n", notes: "", isFavorite: true)
    #expect(entry.accessibilityTitle == "Morning walk, No location added")
    #expect(entry.accessibilityFavoriteState == "Favorite")
}

@Test func rowPreservesUnicodeWithoutDuplicatingTheNoteBody() {
    let notes = String(repeating: "A fictional observation. ", count: 20)
    let entry = JournalEntry(title: "東京散歩", place: " Café ", notes: notes)
    #expect(entry.accessibilityTitle == "東京散歩, Café")
    #expect(entry.accessibilityFavoriteState == "Not a favorite")
    #expect(entry.notes == notes)
}

@MainActor @Test func accessibleLabelsTrackPersistedEditsAndFavorites() async {
    let entry = JournalEntry(title: "Before", place: "Park", notes: " ")
    let storage = FakeStorage(entries: [entry])
    let model = JournalModel(storage: storage)
    await model.load()
    let draft = JournalDraft(entry: entry)
    draft.title = "After"
    #expect(await draft.save(using: model))
    var updated = model.entries
    updated[0].isFavorite = true
    #expect(await model.save(updated))
    #expect(model.entries[0].accessibilityTitle == "After, Park")
    #expect(model.entries[0].accessibilityFavoriteState == "Favorite")
}
