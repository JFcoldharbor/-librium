import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class ObligationsFirestoreService {
    static let shared = ObligationsFirestoreService()

    private let db = Firestore.firestore()

    private init() {}

    private var userCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("obligations")
    }

    func fetchAll() async throws -> [Obligation] {
        guard let coll = userCollection else { return [] }
        let snapshot = try await coll.getDocuments()
        return snapshot.documents.compactMap { doc -> Obligation? in
            guard let id = UUID(uuidString: doc.documentID) else { return nil }
            return Self.decode(id: id, data: doc.data())
        }
    }

    func upsert(_ obligation: Obligation) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(obligation.id.uuidString).setData(Self.encode(obligation), merge: true)
    }

    func delete(id: UUID) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(id.uuidString).delete()
    }

    func listen(onChange: @escaping @MainActor ([Obligation]) -> Void) -> ListenerRegistration? {
        guard let coll = userCollection else { return nil }
        return coll.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { doc -> Obligation? in
                guard let id = UUID(uuidString: doc.documentID) else { return nil }
                return Self.decode(id: id, data: doc.data())
            }
            Task { @MainActor in onChange(items) }
        }
    }

    private static func encode(_ o: Obligation) -> [String: Any] {
        var data: [String: Any] = [
            "id": o.id.uuidString,
            "title": o.title,
            "amount": o.amount,
            "dueDate": Timestamp(date: o.dueDate),
            "recurrence": o.recurrence.rawValue,
            "category": o.category.rawValue,
            "isPaidThisCycle": o.isPaidThisCycle,
            "updatedAt": Timestamp(date: Date())
        ]
        if let cons = o.consequencesIfMissed { data["consequencesIfMissed"] = cons }
        return data
    }

    private static func decode(id: UUID, data: [String: Any]) -> Obligation? {
        guard let title = data["title"] as? String,
              let amount = data["amount"] as? Double,
              let dueTs = data["dueDate"] as? Timestamp,
              let recRaw = data["recurrence"] as? String,
              let recurrence = Obligation.Recurrence(rawValue: recRaw),
              let catRaw = data["category"] as? String,
              let category = Obligation.Category(rawValue: catRaw),
              let isPaid = data["isPaidThisCycle"] as? Bool else {
            return nil
        }
        return Obligation(
            id: id,
            title: title,
            amount: amount,
            dueDate: dueTs.dateValue(),
            recurrence: recurrence,
            category: category,
            consequencesIfMissed: data["consequencesIfMissed"] as? String,
            isPaidThisCycle: isPaid
        )
    }
}
