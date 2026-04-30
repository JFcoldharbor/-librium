import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class GoalsFirestoreService {
    static let shared = GoalsFirestoreService()

    private let db = Firestore.firestore()

    private init() {}

    private var userCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("goals")
    }

    func fetchAll() async throws -> [Goal] {
        guard let coll = userCollection else { return [] }
        let snapshot = try await coll.getDocuments()
        return snapshot.documents.compactMap { doc -> Goal? in
            guard let id = UUID(uuidString: doc.documentID) else { return nil }
            return Self.decode(id: id, data: doc.data())
        }
    }

    func upsert(_ goal: Goal) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(goal.id.uuidString).setData(Self.encode(goal), merge: true)
    }

    func delete(id: UUID) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(id.uuidString).delete()
    }

    func listen(onChange: @escaping @MainActor ([Goal]) -> Void) -> ListenerRegistration? {
        guard let coll = userCollection else { return nil }
        return coll.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { doc -> Goal? in
                guard let id = UUID(uuidString: doc.documentID) else { return nil }
                return Self.decode(id: id, data: doc.data())
            }
            Task { @MainActor in onChange(items) }
        }
    }

    private static func encode(_ g: Goal) -> [String: Any] {
        var data: [String: Any] = [
            "id": g.id.uuidString,
            "title": g.title,
            "timeframe": g.timeframe.rawValue,
            "status": g.status.rawValue,
            "createdAt": Timestamp(date: g.createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
        if let detail = g.detail { data["detail"] = detail }
        if let target = g.targetDate { data["targetDate"] = Timestamp(date: target) }
        if let completed = g.completedAt { data["completedAt"] = Timestamp(date: completed) }
        if let parent = g.parentGoalId { data["parentGoalId"] = parent.uuidString }
        return data
    }

    private static func decode(id: UUID, data: [String: Any]) -> Goal? {
        guard let title = data["title"] as? String,
              let tfRaw = data["timeframe"] as? String,
              let timeframe = Goal.Timeframe(rawValue: tfRaw),
              let statusRaw = data["status"] as? String,
              let status = Goal.Status(rawValue: statusRaw),
              let createdTs = data["createdAt"] as? Timestamp else {
            return nil
        }
        let parent = (data["parentGoalId"] as? String).flatMap { UUID(uuidString: $0) }
        return Goal(
            id: id,
            title: title,
            detail: data["detail"] as? String,
            timeframe: timeframe,
            status: status,
            targetDate: (data["targetDate"] as? Timestamp)?.dateValue(),
            createdAt: createdTs.dateValue(),
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            parentGoalId: parent
        )
    }
}
