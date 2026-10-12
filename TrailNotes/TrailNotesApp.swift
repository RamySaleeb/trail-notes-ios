import SwiftUI

@main
struct TrailNotesApp: App {
    var body: some Scene { WindowGroup { JournalView() } }
}

struct JournalView: View {
    @State private var model = JournalModel()
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var composing = false

    private var visibleEntries: [JournalEntry] {
        JournalQuery.filter(model.entries, text: query, favoritesOnly: favoritesOnly)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("A LITTLE SPACE TO NOTICE", systemImage: "leaf")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("Keep the moments.\nFind your next path.")
                            .font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                        Text("A private journal on this device. No account, no network, just your notes.")
                            .foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                    Toggle("Favorites only", isOn: $favoritesOnly)
                }
                Section("Your field notes · \(visibleEntries.count)") {
                    if model.isBusy { ProgressView("Updating journal") }
                    if !model.isLoaded && !model.isBusy {
                        Button("Try opening journal again") { Task { await model.load() } }
                    } else if model.isLoaded && visibleEntries.isEmpty {
                        ContentUnavailableView("No notes here yet", systemImage: "book.closed",
                                               description: Text("Add a note or change your search and filters."))
                    }
                    ForEach(visibleEntries) { entry in
                        NavigationLink {
                            NoteDetailView(model: model, entryID: entry.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.title).font(.headline)
                                Label(entry.place.isEmpty ? "No location added" : entry.place,
                                      systemImage: entry.isFavorite ? "star.fill" : "mappin")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(entry.notes).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }.padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Trail Notes")
            .searchable(text: $query, prompt: "Search places and moments")
            .toolbar {
                Button("New note", systemImage: "square.and.pencil") { composing = true }
                    .disabled(!model.isLoaded || model.isBusy)
            }
            .sheet(isPresented: $composing) {
                ComposeView(model: model)
            }
            .alert("Journal unavailable", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK", role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
            .task { await model.load() }
            .tint(.green)
        }
    }
}

private struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalDraft
    let model: JournalModel

    init(model: JournalModel, entry: JournalEntry? = nil) {
        self.model = model
        _draft = State(initialValue: JournalDraft(entry: entry))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("The moment") {
                    TextField("Title", text: $draft.title)
                    TextField("Place (optional)", text: $draft.place)
                }
                Section("What did you notice?") {
                    TextEditor(text: $draft.notes).frame(minHeight: 180).accessibilityLabel("Notes")
                }
            }
            .disabled(draft.isSaving)
            .interactiveDismissDisabled(draft.isSaving)
            .alert("Could not save", isPresented: $draft.saveFailed) { Button("OK", role: .cancel) {} } message: { Text("Your draft is still here. Please try saving again.") }
            .navigationTitle(draft.isEditing ? "Edit field note" : "New field note").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(draft.isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await draft.save(using: model) { dismiss() }
                        }
                    }.disabled(draft.isSaving || !draft.canSave)
                }
            }
        }
    }
}

private struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let model: JournalModel
    let entryID: UUID
    @State private var editing: JournalEntry?
    @State private var confirmingDelete = false
    @State private var deleteFailed = false

    var body: some View {
        Group {
            if let entry = model.entries.first(where: { $0.id == entryID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Label(entry.place.isEmpty ? "Somewhere memorable" : entry.place, systemImage: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Text(entry.title).font(.largeTitle.bold())
                        Text(entry.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        Text(entry.notes).font(.body).textSelection(.enabled)
                        Button(entry.isFavorite ? "Remove from favorites" : "Add to favorites",
                               systemImage: entry.isFavorite ? "star.fill" : "star") {
                            var updated = model.entries
                            if let index = updated.firstIndex(where: { $0.id == entryID }) {
                                updated[index].isFavorite.toggle()
                                Task { await model.save(updated) }
                            }
                        }.buttonStyle(.bordered)
                        Button("Edit note", systemImage: "pencil") { editing = entry }
                            .buttonStyle(.bordered)
                        Button("Delete note", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                            .buttonStyle(.bordered)
                    }.disabled(model.isBusy).frame(maxWidth: 680, alignment: .leading).padding()
                }
            } else {
                ContentUnavailableView("Note no longer available", systemImage: "book.closed")
            }
        }
        .navigationTitle("Field note").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { entry in ComposeView(model: model, entry: entry) }
        .alert("Delete this note?", isPresented: $confirmingDelete) {
            Button("Delete note", role: .destructive) {
                Task {
                    if await model.delete(id: entryID, reportError: false) { dismiss() }
                    else { deleteFailed = true }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the note from this device. This cannot be undone.")
        }
        .alert("Could not delete", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your note has been kept. Try Delete note again when you are ready.")
        }
    }
}
