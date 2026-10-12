import Foundation
import Testing
@testable import TrailNotesCore

@MainActor @Test func editingPersistsAndPreservesMetadata() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = JournalRepository(fileURL: directory.appendingPathComponent("journal.json"))
    let original = JournalEntry(title: "Before", place: "Here", notes: "Old", isFavorite: true, createdAt: .distantPast)
    let other = JournalEntry(title: "Other", place: "", notes: "")
    try await repository.save([original, other])
    let model = JournalModel(storage: repository)
    await model.load()
    let draft = JournalDraft(entry: original)
    draft.title = "  After  "
    draft.place = " There "
    draft.notes = "Updated"
    #expect(await draft.save(using: model))
    let reloaded = JournalModel(storage: repository)
    await reloaded.load()
    let edited = try #require(reloaded.entries.first)
    #expect(edited.title == "After" && edited.place == "There" && edited.notes == "Updated")
    #expect(edited.id == original.id && edited.createdAt == original.createdAt && edited.isFavorite)
    #expect(reloaded.entries.last == other && reloaded.entries.count == 2)
}

@MainActor @Test func cancelledAndBlankEditsDoNotWrite() async {
    let original = JournalEntry(title: "Keep", place: "", notes: "")
    let storage = FakeStorage(entries: [original])
    let model = JournalModel(storage: storage)
    await model.load()
    // Cancelling discards this isolated draft without invoking save.
    var draft: JournalDraft? = JournalDraft(entry: original)
    draft?.title = "Uncommitted"
    draft = nil
    #expect(model.entries == [original])
    let blank = JournalDraft(entry: original)
    blank.title = " \n "
    #expect(await blank.save(using: model) == false)
    #expect(await storage.saveCount == 0)
    #expect(await storage.entries == [original])
}

@MainActor @Test func failedEditKeepsDraftAndRetryUpdatesOnce() async {
    let original = JournalEntry(title: "Before", place: "", notes: "")
    let storage = FakeStorage(entries: [original])
    let model = JournalModel(storage: storage)
    await model.load()
    let draft = JournalDraft(entry: original)
    draft.title = "After"
    await storage.failures(save: true)
    #expect(await draft.save(using: model) == false)
    #expect(draft.title == "After" && draft.saveFailed && !draft.isSaving)
    #expect(model.entries == [original] && !model.isBusy)
    #expect(await storage.entries == [original])
    await storage.failures()
    #expect(await draft.save(using: model))
    #expect(model.entries.count == 1 && model.entries.first?.id == original.id)
    #expect(model.entries.first?.title == "After" && !draft.saveFailed)
}

@MainActor @Test func failedDeletePreservesNoteAndRetryRemovesIt() async {
    let original = JournalEntry(title: "Remove", place: "", notes: "")
    let other = JournalEntry(title: "Keep", place: "", notes: "")
    let storage = FakeStorage(entries: [original, other])
    let model = JournalModel(storage: storage)
    await model.load()
    await storage.failures(save: true)
    #expect(await model.delete(id: original.id) == false)
    #expect(model.entries == [original, other] && !model.isBusy && model.error != nil)
    #expect(await storage.entries == [original, other])
    await storage.failures()
    #expect(await model.delete(id: original.id))
    #expect(model.entries == [other] && model.error == nil)
    #expect(await storage.entries == [other])
}

@MainActor @Test func deletingFinalNotePersistsEmptyWithoutReseeding() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = JournalRepository(fileURL: directory.appendingPathComponent("journal.json"))
    let original = JournalEntry(title: "Last", place: "", notes: "")
    try await repository.save([original])
    let model = JournalModel(storage: repository)
    await model.load()
    #expect(await model.delete(id: original.id))
    let reloaded = JournalModel(storage: repository)
    await reloaded.load()
    #expect(reloaded.isLoaded && reloaded.entries.isEmpty)
    #expect(try await repository.load() == [])
}

@MainActor @Test func staleEditCannotResurrectDeletedNote() async {
    let original = JournalEntry(title: "Removed", place: "", notes: "")
    let storage = FakeStorage(entries: [original])
    let model = JournalModel(storage: storage)
    await model.load()
    let draft = JournalDraft(entry: original)
    #expect(await model.delete(id: original.id))
    draft.title = "Stale update"
    #expect(await draft.save(using: model) == false)
    #expect(draft.saveFailed && !draft.isSaving && model.entries.isEmpty)
    #expect(await model.delete(id: original.id) == false)
    #expect(await storage.saveCount == 1)
}
