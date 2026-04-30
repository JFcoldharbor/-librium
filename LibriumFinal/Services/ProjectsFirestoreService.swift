import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class ProjectsFirestoreService {
    static let shared = ProjectsFirestoreService()

    private let db = Firestore.firestore()

    private init() {}

    private var userCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("projects")
    }

    func fetchAll() async throws -> [Project] {
        guard let coll = userCollection else { return [] }
        let snapshot = try await coll.getDocuments()
        return snapshot.documents.compactMap { doc -> Project? in
            guard let id = UUID(uuidString: doc.documentID) else { return nil }
            return Self.decode(id: id, data: doc.data())
        }
    }

    func upsert(_ project: Project) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(project.id.uuidString).setData(Self.encode(project), merge: true)
    }

    func delete(id: UUID) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(id.uuidString).delete()
    }

    func listen(onChange: @escaping @MainActor ([Project]) -> Void) -> ListenerRegistration? {
        guard let coll = userCollection else { return nil }
        return coll.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let items = docs.compactMap { doc -> Project? in
                guard let id = UUID(uuidString: doc.documentID) else { return nil }
                return Self.decode(id: id, data: doc.data())
            }
            Task { @MainActor in onChange(items) }
        }
    }

    private static func encode(_ p: Project) -> [String: Any] {
        var data: [String: Any] = [
            "id": p.id.uuidString,
            "name": p.name,
            "status": p.status.rawValue,
            "milestones": p.milestones.map(encodeMilestone),
            "createdAt": Timestamp(date: p.createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
        if let detail = p.detail { data["detail"] = detail }
        if let deadline = p.deadline { data["deadline"] = Timestamp(date: deadline) }
        return data
    }

    private static func encodeMilestone(_ m: Project.Milestone) -> [String: Any] {
        var data: [String: Any] = [
            "id": m.id.uuidString,
            "name": m.name,
            "isCompleted": m.isCompleted
        ]
        if let due = m.dueDate { data["dueDate"] = Timestamp(date: due) }
        return data
    }

    private static func decode(id: UUID, data: [String: Any]) -> Project? {
        guard let name = data["name"] as? String,
              let statusRaw = data["status"] as? String,
              let status = Project.Status(rawValue: statusRaw),
              let createdTs = data["createdAt"] as? Timestamp else {
            return nil
        }
        let milestones = (data["milestones"] as? [[String: Any]] ?? []).compactMap(decodeMilestone)
        return Project(
            id: id,
            name: name,
            detail: data["detail"] as? String,
            deadline: (data["deadline"] as? Timestamp)?.dateValue(),
            status: status,
            milestones: milestones,
            createdAt: createdTs.dateValue()
        )
    }

    private static func decodeMilestone(_ data: [String: Any]) -> Project.Milestone? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = data["name"] as? String,
              let isCompleted = data["isCompleted"] as? Bool else {
            return nil
        }
        return Project.Milestone(
            id: id,
            name: name,
            dueDate: (data["dueDate"] as? Timestamp)?.dateValue(),
            isCompleted: isCompleted
        )
    }
}
