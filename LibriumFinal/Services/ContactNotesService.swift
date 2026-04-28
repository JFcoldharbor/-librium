import Foundation

@MainActor
final class ContactNotesService: ObservableObject {
    static let shared = ContactNotesService()

    @Published private(set) var notesByContactId: [String: ContactNote] = [:]

    private let store: JSONStore
    private static let storageKey = "equilibrium.network.contactNotes"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        let array = store.load([ContactNote].self, key: Self.storageKey) ?? []
        var map: [String: ContactNote] = [:]
        for note in array { map[note.contactId] = note }
        notesByContactId = map
    }

    func note(for contactId: String) -> ContactNote {
        notesByContactId[contactId] ?? ContactNote.empty(contactId: contactId)
    }

    func upsert(_ note: ContactNote) {
        var updated = note
        // Preserve any field the caller didn't explicitly pass — tools/sheets focused on one concern
        // shouldn't accidentally erase fields they don't care about.
        if let existing = notesByContactId[note.contactId] {
            if updated.lastTouchedAt == nil {
                updated.lastTouchedAt = existing.lastTouchedAt
            }
            if updated.lastTouchChannel == nil {
                updated.lastTouchChannel = existing.lastTouchChannel
            }
            if updated.relationshipType == .unknown && existing.relationshipType != .unknown {
                updated.relationshipType = existing.relationshipType
            }
            if updated.personalScore == nil {
                updated.personalScore = existing.personalScore
            }
            if updated.businessScore == nil {
                updated.businessScore = existing.businessScore
            }
            if updated.relationshipContext == nil {
                updated.relationshipContext = existing.relationshipContext
            }
        }
        updated.updatedAt = Date()
        notesByContactId[note.contactId] = updated
        persist()
    }

    /// Explicit clear — for the rare case a future UI wants to wipe last-touch.
    func clearLastTouch(contactId: String) {
        guard var existing = notesByContactId[contactId] else { return }
        existing.lastTouchedAt = nil
        existing.lastTouchChannel = nil
        existing.updatedAt = Date()
        notesByContactId[contactId] = existing
        persist()
    }

    /// Explicit clear — bypasses upsert's preserve-on-nil merge.
    func clearSentiment(contactId: String) {
        guard var existing = notesByContactId[contactId] else { return }
        existing.personalScore = nil
        existing.businessScore = nil
        existing.relationshipContext = nil
        existing.updatedAt = Date()
        notesByContactId[contactId] = existing
        persist()
    }

    func delete(contactId: String) {
        notesByContactId.removeValue(forKey: contactId)
        persist()
    }

    func upcomingFollowUps(within days: Int = 14, now: Date = Date()) -> [ContactNote] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: days, to: now) else { return [] }
        return notesByContactId.values
            .filter { note in
                guard let due = note.nextFollowUp else { return false }
                return due >= calendar.startOfDay(for: now) && due <= cutoff
            }
            .sorted { ($0.nextFollowUp ?? .distantFuture) < ($1.nextFollowUp ?? .distantFuture) }
    }

    private func persist() {
        store.save(Array(notesByContactId.values), key: Self.storageKey)
    }
}
