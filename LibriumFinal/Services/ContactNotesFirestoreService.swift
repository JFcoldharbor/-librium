import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class ContactNotesFirestoreService {
    static let shared = ContactNotesFirestoreService()

    private let db = Firestore.firestore()

    private init() {}

    private var userCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("contactNotes")
    }

    func fetchAll() async throws -> [ContactNote] {
        guard let coll = userCollection else { return [] }
        let snapshot = try await coll.getDocuments()
        return snapshot.documents.compactMap { Self.decode(data: $0.data()) }
    }

    func upsert(_ note: ContactNote) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(safeDocId(note.contactId)).setData(Self.encode(note), merge: true)
    }

    func delete(contactId: String) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(safeDocId(contactId)).delete()
    }

    func listen(onChange: @escaping @MainActor ([ContactNote]) -> Void) -> ListenerRegistration? {
        guard let coll = userCollection else { return nil }
        return coll.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { Self.decode(data: $0.data()) }
            Task { @MainActor in onChange(items) }
        }
    }

    /// Firestore document IDs can't contain '/', and a few other characters are awkward.
    /// Contact identifiers from CNContact look like simple UUIDs but we sanitize defensively.
    private func safeDocId(_ contactId: String) -> String {
        contactId.replacingOccurrences(of: "/", with: "_")
    }

    private static func encode(_ n: ContactNote) -> [String: Any] {
        var data: [String: Any] = [
            "contactId": n.contactId,
            "notes": n.notes,
            "status": n.status.rawValue,
            "relationshipType": n.relationshipType.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]
        if let f = n.nextFollowUp { data["nextFollowUp"] = Timestamp(date: f) }
        if let r = n.followUpReason { data["followUpReason"] = r }
        if let t = n.lastTouchedAt { data["lastTouchedAt"] = Timestamp(date: t) }
        if let c = n.lastTouchChannel { data["lastTouchChannel"] = c }
        if let p = n.personalScore { data["personalScore"] = p }
        if let b = n.businessScore { data["businessScore"] = b }
        if let ctx = n.relationshipContext { data["relationshipContext"] = ctx }
        return data
    }

    private static func decode(data: [String: Any]) -> ContactNote? {
        guard let contactId = data["contactId"] as? String,
              let notes = data["notes"] as? String,
              let updatedTs = data["updatedAt"] as? Timestamp else {
            return nil
        }
        let status = (data["status"] as? String).flatMap { ContactNote.Status(rawValue: $0) } ?? .active
        let relType = (data["relationshipType"] as? String).flatMap { ContactNote.RelationshipType(rawValue: $0) } ?? .unknown

        return ContactNote(
            contactId: contactId,
            notes: notes,
            nextFollowUp: (data["nextFollowUp"] as? Timestamp)?.dateValue(),
            followUpReason: data["followUpReason"] as? String,
            status: status,
            lastTouchedAt: (data["lastTouchedAt"] as? Timestamp)?.dateValue(),
            lastTouchChannel: data["lastTouchChannel"] as? String,
            relationshipType: relType,
            personalScore: data["personalScore"] as? Int,
            businessScore: data["businessScore"] as? Int,
            relationshipContext: data["relationshipContext"] as? String,
            updatedAt: updatedTs.dateValue()
        )
    }
}
