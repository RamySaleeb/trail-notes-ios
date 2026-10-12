import Foundation

extension JournalEntry {
    /// A row is one navigation target. Include state conveyed visually by its icon.
    public var accessibilitySummary: String {
        let location = place.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [title, location.isEmpty ? "No location added" : location,
                     isFavorite ? "Favorite" : "Not a favorite"]
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(notes)
        }
        return parts.joined(separator: ". ")
    }
}
