import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class DealsFirestoreService {
    static let shared = DealsFirestoreService()

    private let db = Firestore.firestore()

    private init() {}

    private var userCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("deals")
    }

    func fetchAll() async throws -> [PipelineDeal] {
        guard let coll = userCollection else { return [] }
        let snapshot = try await coll.getDocuments()
        return snapshot.documents.compactMap { doc -> PipelineDeal? in
            guard let id = UUID(uuidString: doc.documentID) else { return nil }
            return Self.decode(id: id, data: doc.data())
        }
    }

    func upsert(_ deal: PipelineDeal) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(deal.id.uuidString).setData(Self.encode(deal), merge: true)
    }

    func delete(id: UUID) async throws {
        guard let coll = userCollection else { throw FirestoreSyncError.notAuthenticated }
        try await coll.document(id.uuidString).delete()
    }

    func listen(onChange: @escaping @MainActor ([PipelineDeal]) -> Void) -> ListenerRegistration? {
        guard let coll = userCollection else { return nil }
        return coll.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let deals = docs.compactMap { doc -> PipelineDeal? in
                guard let id = UUID(uuidString: doc.documentID) else { return nil }
                return Self.decode(id: id, data: doc.data())
            }
            Task { @MainActor in
                onChange(deals)
            }
        }
    }

    private static func encode(_ deal: PipelineDeal) -> [String: Any] {
        var data: [String: Any] = [
            "id": deal.id.uuidString,
            "name": deal.name,
            "contactName": deal.contactName,
            "stage": deal.stage.rawValue,
            "dealValue": deal.dealValue,
            "probability": deal.probability,
            "createdAt": Timestamp(date: deal.createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
        if let email = deal.contactEmail { data["contactEmail"] = email }
        if let action = deal.nextAction { data["nextAction"] = action }
        if let date = deal.nextActionDate { data["nextActionDate"] = Timestamp(date: date) }
        if let last = deal.lastContact { data["lastContact"] = Timestamp(date: last) }
        if let notes = deal.notes { data["notes"] = notes }
        return data
    }

    private static func decode(id: UUID, data: [String: Any]) -> PipelineDeal? {
        guard let name = data["name"] as? String,
              let contactName = data["contactName"] as? String,
              let stageRaw = data["stage"] as? String,
              let stage = PipelineDeal.Stage(rawValue: stageRaw),
              let dealValue = data["dealValue"] as? Double,
              let probability = data["probability"] as? Double,
              let createdTs = data["createdAt"] as? Timestamp else {
            return nil
        }
        return PipelineDeal(
            id: id,
            name: name,
            contactName: contactName,
            contactEmail: data["contactEmail"] as? String,
            stage: stage,
            dealValue: dealValue,
            probability: probability,
            nextAction: data["nextAction"] as? String,
            nextActionDate: (data["nextActionDate"] as? Timestamp)?.dateValue(),
            lastContact: (data["lastContact"] as? Timestamp)?.dateValue(),
            notes: data["notes"] as? String,
            createdAt: createdTs.dateValue()
        )
    }
}

enum FirestoreSyncError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in."
        }
    }
}
