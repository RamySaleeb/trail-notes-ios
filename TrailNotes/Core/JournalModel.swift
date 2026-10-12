import Foundation
import Observation

@MainActor @Observable
public final class JournalModel {
    public private(set) var entries: [JournalEntry] = []
    public private(set) var isBusy = false
    public private(set) var isLoaded = false
    public var error: String?
    private let storage: any JournalStorage

    public init(storage: (any JournalStorage)? = nil) {
        self.storage = storage ?? JournalRepository(fileURL: URL.applicationSupportDirectory
            .appending(path: "TrailNotes/journal.json"))
    }

    public func load() async {
        guard !isLoaded, !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            entries = try await storage.load() ?? JournalEntry.samples
            isLoaded = true
        } catch {
            self.error = "Your journal could not be opened. Existing data has been kept safe. Please try again."
        }
    }

    /// Reject overlapping operations rather than queueing stale snapshots.
    /// Only successful persistence commits new visible state.
    @discardableResult
    public func save(_ updated: [JournalEntry], reportError: Bool = true) async -> Bool {
        guard isLoaded, !isBusy else { return false }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            try await storage.save(updated)
            entries = updated
            return true
        } catch {
            if reportError { self.error = "Your changes could not be saved. Please try again." }
            return false
        }
    }
}

/// Owns compose state so a failed save never discards the user's draft.
@MainActor @Observable
public final class JournalDraft {
    public var title = ""
    public var place = ""
    public var notes = ""
    public private(set) var isSaving = false
    public var saveFailed = false
    public var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public init() {}

    public func save(using model: JournalModel) async -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        saveFailed = false
        defer { isSaving = false }
        let entry = JournalEntry(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                 place: place.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes)
        // The sheet owns its failure alert; don't also present an underlying alert.
        let saved = await model.save([entry] + model.entries, reportError: false)
        saveFailed = !saved
        return saved
    }
}
