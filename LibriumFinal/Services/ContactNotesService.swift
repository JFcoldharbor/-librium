import FirebaseFirestore
import Foundation

@MainActor
final class ContactNotesService: ObservableObject {
    static let shared = ContactNotesService()

    @Published private(set) var notesByContactId: [String: ContactNote] = [:]

    private let store: JSONStore
    private static let storageKey = "equilibrium.network.contactNotes"
    private static let migrationFlagKey = "equilibrium.network.contactNotes.firestoreMigrated"

    private var listener: ListenerRegistration?

    init(store: JSONStore = .shared) {
        self.store = store
        load()
        startSync()
    }

    deinit {
        listener?.remove()
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
        let snapshot = updated
        Task { try? await ContactNotesFirestoreService.shared.upsert(snapshot) }
    }

    func clearLastTouch(contactId: String) {
        guard var existing = notesByContactId[contactId] else { return }
        existing.lastTouchedAt = nil
        existing.lastTouchChannel = nil
        existing.updatedAt = Date()
        notesByContactId[contactId] = existing
        persist()
        Task { try? await ContactNotesFirestoreService.shared.upsert(existing) }
    }

    func clearSentiment(contactId: String) {
        guard var existing = notesByContactId[contactId] else { return }
        existing.personalScore = nil
        existing.businessScore = nil
        existing.relationshipContext = nil
        existing.updatedAt = Date()
        notesByContactId[contactId] = existing
        persist()
        Task { try? await ContactNotesFirestoreService.shared.upsert(existing) }
    }

    func delete(contactId: String) {
        notesByContactId.removeValue(forKey: contactId)
        persist()
        Task { try? await ContactNotesFirestoreService.shared.delete(contactId: contactId) }
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

    private func startSync() {
        Task { [weak self] in
            await self?.migrateLocalIfNeeded()
            await MainActor.run { self?.attachListener() }
        }
    }

    private func attachListener() {
        listener?.remove()
        listener = ContactNotesFirestoreService.shared.listen { [weak self] remote in
            guard let self else { return }
            var map: [String: ContactNote] = [:]
            for note in remote { map[note.contactId] = note }
            self.notesByContactId = map
            self.persist()
        }
    }

    private func migrateLocalIfNeeded() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.migrationFlagKey) { return }
        let local = await MainActor.run { Array(self.notesByContactId.values) }
        guard !local.isEmpty else {
            defaults.set(true, forKey: Self.migrationFlagKey)
            return
        }
        do {
            let remote = try await ContactNotesFirestoreService.shared.fetchAll()
            if remote.isEmpty {
                for note in local {
                    try? await ContactNotesFirestoreService.shared.upsert(note)
                }
            }
            defaults.set(true, forKey: Self.migrationFlagKey)
        } catch {}
    }
}
