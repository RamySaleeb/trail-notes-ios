import Foundation
import Testing
@testable import TrailNotesCore

private actor FakeStorage: JournalStorage {
    enum Failure: Error { case simulated }
    var entries: [JournalEntry]?
    var failLoad = false
    var failSave = false
    var loadCount = 0
    var saveCount = 0
    var gate: CheckedContinuation<Void, Never>?
    var started: CheckedContinuation<Void, Never>?
    var holdSave = false

    init(entries: [JournalEntry]? = []) { self.entries = entries }
    func failures(load: Bool = false, save: Bool = false) { failLoad = load; failSave = save }
    func load() throws -> [JournalEntry]? {
        loadCount += 1
        if failLoad { throw Failure.simulated }
        return entries
    }
    func holdNextSave() { holdSave = true }
    func waitForSave() async {
        if gate != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func releaseSave() { gate?.resume(); gate = nil }
    func save(_ entries: [JournalEntry]) async throws {
        saveCount += 1
        if holdSave {
            holdSave = false
            await withCheckedContinuation { gate = $0; started?.resume(); started = nil }
        }
        if failSave { throw Failure.simulated }
        self.entries = entries
    }
}

@MainActor @Test func loadFailureCanRetryWithoutSeedingOrWriting() async {
    let saved = [JournalEntry(title: "Existing", place: "", notes: "")]
    let storage = FakeStorage(entries: saved)
    let model = JournalModel(storage: storage)
    await storage.failures(load: true)
    await model.load()
    #expect(!model.isBusy && !model.isLoaded)
    #expect(model.entries.isEmpty && model.error != nil)
    #expect(await storage.saveCount == 0)
    #expect(await model.save([]) == false)
    await storage.failures()
    await model.load()
    #expect(model.entries == saved && model.isLoaded && !model.isBusy)
    #expect(model.error == nil)
    await model.load()
    #expect(await storage.loadCount == 2)
}

@MainActor @Test func failedSavePreservesEntriesAndRetryCommits() async {
    let saved = [JournalEntry(title: "Existing", place: "", notes: "")]
    let updated = [JournalEntry(title: "New", place: "", notes: "")]
    let storage = FakeStorage(entries: saved)
    let model = JournalModel(storage: storage)
    await model.load()
    await storage.failures(save: true)
    #expect(await model.save(updated) == false)
    #expect(model.entries == saved && !model.isBusy && model.error != nil)
    #expect(await storage.entries == saved)
    await storage.failures()
    #expect(await model.save(updated))
    #expect(model.entries == updated && !model.isBusy && model.error == nil)
    #expect(await storage.entries == updated)
}

@MainActor @Test func emptyJournalIsNotSeededButMissingJournalIs() async {
    let empty = JournalModel(storage: FakeStorage(entries: []))
    await empty.load()
    #expect(empty.entries.isEmpty && empty.isLoaded)
    let missing = JournalModel(storage: FakeStorage(entries: nil))
    await missing.load()
    #expect(missing.entries == JournalEntry.samples)
}

@MainActor @Test func overlappingSaveIsRejectedWithoutLosingFirstCommit() async {
    let storage = FakeStorage()
    let model = JournalModel(storage: storage)
    await model.load()
    await storage.holdNextSave()
    let first = [JournalEntry(title: "First", place: "", notes: "")]
    let operation = Task { await model.save(first) }
    await storage.waitForSave()
    #expect(model.isBusy)
    #expect(await model.save([]) == false)
    #expect(await storage.saveCount == 1)
    await storage.releaseSave()
    #expect(await operation.value)
    #expect(model.entries == first && !model.isBusy)
}

@MainActor @Test func composeDraftSurvivesFailureAndRetriesWithoutDuplicates() async {
    let storage = FakeStorage()
    let model = JournalModel(storage: storage)
    await model.load()
    let draft = JournalDraft()
    draft.title = "  My note  "
    draft.place = " Garden "
    draft.notes = "Keep this text"
    await storage.failures(save: true)
    #expect(await draft.save(using: model) == false)
    #expect(draft.title == "  My note  " && draft.notes == "Keep this text")
    #expect(draft.place == " Garden " && draft.saveFailed && !draft.isSaving)
    #expect(model.entries.isEmpty && model.error == nil)
    await storage.failures()
    #expect(await draft.save(using: model))
    #expect(!draft.isSaving && !draft.saveFailed)
    #expect(model.entries.count == 1)
    #expect(model.entries.first?.title == "My note")
    #expect(model.entries.first?.place == "Garden")
}

@MainActor @Test func blankDraftNeverWrites() async {
    let storage = FakeStorage()
    let model = JournalModel(storage: storage)
    await model.load()
    let draft = JournalDraft()
    draft.title = " \n "
    #expect(await draft.save(using: model) == false)
    #expect(!draft.isSaving)
    #expect(await storage.saveCount == 0)
}
