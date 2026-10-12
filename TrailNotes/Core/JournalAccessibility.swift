import Foundation

extension JournalEntry {
    /// Keep the row concise; its navigation action exposes the complete note.
    public var accessibilityTitle: String {
        let location = place.trimmingCharacters(in: .whitespacesAndNewlines)
        return title + ", " + (location.isEmpty ? "No location added" : location)
    }

    /// Expose the state independently of the star icon and action label.
    public var accessibilityFavoriteState: String {
        isFavorite ? "Favorite" : "Not a favorite"
    }
}
