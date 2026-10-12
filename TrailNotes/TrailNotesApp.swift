import SwiftUI

@main
struct TrailNotesApp: App {
  var body: some Scene { WindowGroup { JournalView() } }
}

private enum JournalFocus: Hashable {
  case newNote, retry
  case favorite(UUID), edit(UUID)
}

private struct ComposeRoute: Identifiable {
  let id = UUID()
  let entry: JournalEntry?
}

struct JournalView: View {
  @State private var model = JournalModel(storage: UITestStorage.configured)
  @State private var query = ""
  @State private var favoritesOnly = false
  @State private var composeRoute: ComposeRoute?
  @State private var composerOrigin: JournalFocus = .newNote
  @Environment(\.dynamicTypeSize) private var textSize
  @AccessibilityFocusState private var accessibilityFocus: JournalFocus?
  @State private var lastFavorite: UUID?

  private var visibleEntries: [JournalEntry] {
    JournalQuery.filter(model.entries, text: query, favoritesOnly: favoritesOnly)
  }

  private func entryLink(_ entry: JournalEntry) -> some View {
    NavigationLink {
      NoteDetailView(model: model, original: entry, focus: $accessibilityFocus,
        onFavorite: { lastFavorite = entry.id },
        onEdit: { note in composerOrigin = .edit(note.id); composeRoute = ComposeRoute(entry: note) })
    } label: {
      NoteRow(entry: entry)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          Text(entry.accessibilityTitle)
        )
        .accessibilityValue(entry.accessibilityFavoriteState)
    }
    .accessibilityHint("Opens the full note")
    .accessibilityIdentifier("note-\(entry.id.uuidString)")
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            Text(
              textSize.isAccessibilitySize
                ? "Your journal" : "Keep the moments. Find your next path."
            )
            .font(.title.bold()).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            Text("Private notes, stored on this device.")
              .foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
          }.padding(.vertical, 12)
          Toggle("Favorites only", isOn: $favoritesOnly)
            .accessibilityIdentifier("favoritesFilter")
        }
        Section("Your field notes · \(visibleEntries.count)") {
          if model.isBusy {
            ProgressView("Updating journal").accessibilityIdentifier("journalProgress")
          }
          if !model.isLoaded && !model.isBusy {
            Button("Try opening journal again") { Task { await model.load() } }
              .accessibilityFocused($accessibilityFocus, equals: .retry)
              .accessibilityIdentifier("retryLoad")
          } else if model.isLoaded && visibleEntries.isEmpty {
            ContentUnavailableView(
              "No notes here yet", systemImage: "book.closed",
              description: Text("Add a note or change your search and filters.")
            )
            .accessibilityIdentifier("emptyResults")
          }
          ForEach(visibleEntries) { entry in
            entryLink(entry)
          }
        }
      }
      .navigationTitle("Trail Notes")
      .searchable(
        text: $query,
        placement: .navigationBarDrawer(displayMode: .always), prompt: "Search"
      )
      .toolbar {
        Button("New note", systemImage: "square.and.pencil") {
          composerOrigin = .newNote
          composeRoute = ComposeRoute(entry: nil)
        }
          .keyboardShortcut("n", modifiers: .command)
          .disabled(!model.isLoaded || model.isBusy)
          .accessibilityFocused($accessibilityFocus, equals: .newNote)
          .accessibilityIdentifier("newNote")
      }
      .task { await model.load() }
      .tint(.accentColor)
    }
    .sheet(item: $composeRoute, onDismiss: { accessibilityFocus = composerOrigin }) { route in
      ComposeView(model: model, entry: route.entry, onClose: { composeRoute = nil })
    }
    .alert(
      "Journal unavailable",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("OK", role: .cancel) {
        model.error = nil
        accessibilityFocus = model.isLoaded ? lastFavorite.map(JournalFocus.favorite) : .retry
      }
    } message: {
      Text(model.error ?? "")
    }
    .preferredColorScheme(UITestStorage.colorScheme)
  }
}

private struct NoteDetailView: View {
  @Environment(\.dismiss) private var dismiss
  let model: JournalModel
  let original: JournalEntry
  let focus: AccessibilityFocusState<JournalFocus?>.Binding
  let onFavorite: () -> Void
  let onEdit: (JournalEntry) -> Void
  @State private var confirmingDelete = false
  @State private var deleteFailed = false
  private enum Action: Hashable { case delete }
  @AccessibilityFocusState private var actionFocus: Action?

  var body: some View {
    Group {
      if let entry = model.entries.first(where: { $0.id == original.id }) {
        content(entry)
      } else {
        ContentUnavailableView("Note no longer available", systemImage: "book.closed")
      }
    }
    .navigationTitle("Field note").navigationBarTitleDisplayMode(.inline)
    .alert("Delete this note?", isPresented: $confirmingDelete) {
      Button("Delete note", role: .destructive) {
        Task {
          if await model.delete(id: original.id, reportError: false) {
            dismiss()
          } else {
            deleteFailed = true
          }
        }
      }
      Button("Cancel", role: .cancel) { actionFocus = .delete }
    } message: {
      Text("This removes the note from this device. This cannot be undone.")
    }
    .alert("Could not delete", isPresented: $deleteFailed) {
      Button("OK", role: .cancel) { actionFocus = .delete }
    } message: {
      Text("Your note has been kept. Try Delete note again when you are ready.")
    }
  }

  private func content(_ entry: JournalEntry) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(entry.title).font(.largeTitle.bold()).accessibilityIdentifier("detailTitle")
          .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
        Label(
          entry.place.isEmpty ? "No location added" : entry.place, systemImage: "mappin.and.ellipse"
        )
        .foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        Text("Created \(entry.createdAt.formatted(date: .long, time: .omitted))")
          .font(.caption).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        Text(entry.notes).font(.body).textSelection(.enabled).fixedSize(
          horizontal: false, vertical: true)
        Button {
          onFavorite()
          var updated = model.entries
          if let index = updated.firstIndex(where: { $0.id == entry.id }) {
            updated[index].isFavorite.toggle()
            Task { await model.save(updated) }
          }
        } label: {
          Label(
            entry.isFavorite ? "Remove from favorites" : "Add to favorites",
            systemImage: entry.isFavorite ? "star.fill" : "star"
          )
          .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }
        .buttonStyle(.bordered).foregroundStyle(.primary).tint(.primary)
        .accessibilityValue(entry.accessibilityFavoriteState)
        .accessibilityFocused(focus, equals: .favorite(entry.id))
        .accessibilityIdentifier("favoriteNote")
        Button {
          onEdit(entry)
        } label: {
          Label("Edit note", systemImage: "pencil")
            .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }.buttonStyle(.bordered).foregroundStyle(.primary).tint(.primary).accessibilityIdentifier(
          "editNote"
        )
        .accessibilityFocused(focus, equals: .edit(entry.id))
        Button(role: .destructive) {
          confirmingDelete = true
        } label: {
          Label("Delete note", systemImage: "trash")
            .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }.buttonStyle(.bordered).foregroundStyle(.primary).tint(.primary).accessibilityIdentifier("deleteNote")
          .accessibilityFocused($actionFocus, equals: .delete)
      }.disabled(model.isBusy).frame(maxWidth: 680, alignment: .leading).padding()
    }
  }
}

private struct NoteRow: View {
  let entry: JournalEntry
  @Environment(\.dynamicTypeSize) private var textSize
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(entry.title).font(.headline).fixedSize(horizontal: false, vertical: true)
      Label(entry.place.isEmpty ? "No location added" : entry.place, systemImage: "mappin")
        .font(.subheadline).foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      if entry.isFavorite { Label("Favorite", systemImage: "star.fill").font(.subheadline) }
      Text(entry.notes).font(.subheadline).foregroundStyle(.primary)
        .lineLimit(textSize.isAccessibilitySize ? nil : 2)
        .fixedSize(horizontal: false, vertical: true)
    }.padding(.vertical, 8)
  }
}

private struct ComposeView: View {
  let onClose: () -> Void
  @State private var draft: JournalDraft
  private enum Field: Hashable { case title, place, notes }
  @FocusState private var field: Field?
  @AccessibilityFocusState private var accessibilityField: Field?
  let model: JournalModel

  init(model: JournalModel, entry: JournalEntry? = nil, onClose: @escaping () -> Void) {
    self.onClose = onClose
    self.model = model
    _draft = State(initialValue: JournalDraft(entry: entry))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading) {
            Text("Title (required)").font(.headline).fixedSize(horizontal: false, vertical: true)
              .accessibilityHidden(true)
            TextField("", text: $draft.title, axis: .vertical)
              .accessibilityLabel("Title, required").accessibilityIdentifier("draftTitle")
              .focused($field, equals: .title).accessibilityFocused(
                $accessibilityField, equals: .title
              )
              .submitLabel(.next).onSubmit { field = .place }
          }
          VStack(alignment: .leading) {
            Text("Place (optional)").font(.headline).fixedSize(horizontal: false, vertical: true)
              .accessibilityHidden(true)
            TextField("", text: $draft.place, axis: .vertical)
              .accessibilityLabel("Place, optional").accessibilityIdentifier("draftPlace")
              .focused($field, equals: .place).accessibilityFocused(
                $accessibilityField, equals: .place
              )
              .submitLabel(.next).onSubmit { field = .notes }
          }
        }
        Section {
          VStack(alignment: .leading) {
            Text("Notes").font(.headline).fixedSize(horizontal: false, vertical: true)
              .accessibilityHidden(true)
            TextEditor(text: $draft.notes).frame(minHeight: 180)
              .accessibilityLabel("Notes").accessibilityIdentifier("draftNotes")
              .focused($field, equals: .notes).accessibilityFocused(
                $accessibilityField, equals: .notes)
          }
        }
      }
      .tint(.primary)
      .scrollDismissesKeyboard(.interactively)
      .disabled(draft.isSaving)
      .interactiveDismissDisabled(draft.isSaving)
      .alert("Could not save", isPresented: $draft.saveFailed) {
        Button("OK", role: .cancel) {
          field = .notes
          accessibilityField = .notes
        }
      } message: {
        Text("Your draft is still here. Please try saving again.")
      }
      .navigationTitle(draft.isEditing ? "Edit field note" : "New field note")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { onClose() }.disabled(draft.isSaving)
            .accessibilityIdentifier("cancelNote")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(draft.isSaving ? "Saving" : "Save") {
            Task { if await draft.save(using: model) { onClose() } }
          }.keyboardShortcut("s", modifiers: .command)
            .disabled(draft.isSaving || !draft.canSave).accessibilityIdentifier("saveNote")
        }
        ToolbarItemGroup(placement: .keyboard) {
          Button("Previous field", systemImage: "chevron.up") {
            field = field == .notes ? .place : .title
          }
          .disabled(field == .title || field == nil)
          Button("Next field", systemImage: "chevron.down") {
            field = field == .title ? .place : .notes
          }
          .disabled(field == .notes || field == nil)
          Spacer()
          Button("Done") { field = nil }
        }
      }
      .defaultFocus($field, .title)
      .onAppear {
        field = .title
        accessibilityField = .title
      }
    }
    .onKeyPress(keys: [.tab], phases: .down) { press in
      guard !draft.isSaving else { return .ignored }
      // Leave boundary navigation to the system; never trap Tab inside the fields.
      switch (field, press.modifiers.contains(.shift)) {
      case (.title, false), (.notes, true): field = .place
      case (.place, false): field = .notes
      case (.place, true): field = .title
      default: return .ignored
      }
      return .handled
    }
  }
}

// Test-only in-memory fixtures never read or overwrite a real journal.
private enum UITestStorage {
  static var configured: (any JournalStorage)? {
    #if DEBUG
      if let scenario = ProcessInfo.processInfo.environment["TRAIL_NOTES_UI_TEST"] {
        return AccessibilityFixtureStorage(
          failsLoad: scenario == "load-error", failsSave: scenario == "save-error")
      }
    #endif
    return nil
  }
  static var colorScheme: ColorScheme? {
    #if DEBUG
      if ProcessInfo.processInfo.environment["TRAIL_NOTES_UI_TEST"] != nil {
        return ProcessInfo.processInfo.environment["TRAIL_NOTES_APPEARANCE"] == "dark"
          ? .dark : .light
      }
    #endif
    return nil
  }
}

#if DEBUG
  @MainActor private final class AccessibilityFixtureStorage: JournalStorage {
    private var failsLoad: Bool
    private var failsSave: Bool
    init(failsLoad: Bool, failsSave: Bool) {
      self.failsLoad = failsLoad
      self.failsSave = failsSave
    }
    func load() async throws -> [JournalEntry]? {
      if failsLoad {
        failsLoad = false
        throw CocoaError(.fileReadUnknown)
      }
      return [
        JournalEntry(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          title: "A quiet morning beside the winding river",
          place: "Willow trail", notes: "Sunlight across the water. A small moment worth keeping.",
          isFavorite: true, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
      ]
    }
    func save(_ entries: [JournalEntry]) async throws {
      if failsSave {
        failsSave = false
        throw CocoaError(.fileWriteUnknown)
      }
    }
  }
#endif
