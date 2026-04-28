import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class FirestoreEventService {
    static let shared = FirestoreEventService()

    enum FirestoreEventError: LocalizedError {
        case notHost
        case notFound
        case underlying(String)

        var errorDescription: String? {
            switch self {
            case .notHost: return "You're not the host of this event."
            case .notFound: return "Event not found."
            case .underlying(let m): return m
            }
        }
    }

    private let db = Firestore.firestore()
    private static let collection = "events"

    private init() {}

    // MARK: - Auth

    @discardableResult
    private func ensureAuthenticated() async throws -> User {
        if let user = Auth.auth().currentUser {
            return user
        }
        let result = try await Auth.auth().signInAnonymously()
        return result.user
    }

    // MARK: - Reads

    func fetch(id: UUID) async throws -> NetworkEvent? {
        _ = try await ensureAuthenticated()
        let snapshot = try await db.collection(Self.collection).document(id.uuidString).getDocument()
        guard let data = snapshot.data() else { return nil }
        return decode(id: id, data: data)
    }

    func myHostedEvents() async throws -> [NetworkEvent] {
        let user = try await ensureAuthenticated()
        let snapshot = try await db.collection(Self.collection)
            .whereField("hostUserId", isEqualTo: user.uid)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            guard let id = UUID(uuidString: doc.documentID) else { return nil }
            return decode(id: id, data: doc.data())
        }
    }

    // MARK: - Writes

    @discardableResult
    func upload(_ event: NetworkEvent) async throws -> NetworkEvent {
        let user = try await ensureAuthenticated()

        var event = event
        if event.hostUserId == nil {
            event.hostUserId = user.uid
        }
        guard event.hostUserId == user.uid else {
            throw FirestoreEventError.notHost
        }

        let data = encode(event)
        try await db.collection(Self.collection).document(event.id.uuidString).setData(data, merge: true)
        return event
    }

    func rsvp(eventId: UUID, attendee: NetworkEvent.Attendee) async throws {
        _ = try await ensureAuthenticated()
        var attDict = encodeAttendee(attendee)
        attDict["joinedAt"] = Timestamp(date: Date())
        try await db.collection(Self.collection).document(eventId.uuidString).updateData([
            "attendees": FieldValue.arrayUnion([attDict]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    func delete(id: UUID) async throws {
        _ = try await ensureAuthenticated()
        try await db.collection(Self.collection).document(id.uuidString).delete()
    }

    // MARK: - Encode

    private func encode(_ event: NetworkEvent) -> [String: Any] {
        var data: [String: Any] = [
            "id": event.id.uuidString,
            "name": event.name,
            "startDate": Timestamp(date: event.startDate),
            "endDate": Timestamp(date: event.endDate),
            "createdAt": Timestamp(date: event.addedAt),
            "updatedAt": Timestamp(date: Date()),
            "attendees": event.attendees.map(encodeAttendee)
        ]
        if let venue = event.venue { data["venue"] = venue }
        if let lat = event.latitude { data["latitude"] = lat }
        if let lng = event.longitude { data["longitude"] = lng }
        if let host = event.host { data["host"] = host }
        if let hostEmail = event.hostEmail { data["hostEmail"] = hostEmail }
        if let hostUserId = event.hostUserId { data["hostUserId"] = hostUserId }
        return data
    }

    private func encodeAttendee(_ attendee: NetworkEvent.Attendee) -> [String: Any] {
        var dict: [String: Any] = [
            "id": attendee.id.uuidString,
            "name": attendee.name
        ]
        if let email = attendee.email { dict["email"] = email }
        if let role = attendee.role { dict["role"] = role }
        if let org = attendee.organization { dict["organization"] = org }
        if let cid = attendee.contactId { dict["contactId"] = cid }
        return dict
    }

    // MARK: - Decode

    private func decode(id: UUID, data: [String: Any]) -> NetworkEvent? {
        guard let name = data["name"] as? String else { return nil }
        let startTs = data["startDate"] as? Timestamp
        let endTs = data["endDate"] as? Timestamp
        let createdTs = data["createdAt"] as? Timestamp
        let attendeesRaw = data["attendees"] as? [[String: Any]] ?? []

        return NetworkEvent(
            id: id,
            name: name,
            venue: data["venue"] as? String,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            startDate: startTs?.dateValue() ?? Date(),
            endDate: endTs?.dateValue() ?? Date(),
            host: data["host"] as? String,
            hostEmail: data["hostEmail"] as? String,
            hostUserId: data["hostUserId"] as? String,
            attendees: attendeesRaw.compactMap(decodeAttendee),
            addedAt: createdTs?.dateValue() ?? Date()
        )
    }

    private func decodeAttendee(_ dict: [String: Any]) -> NetworkEvent.Attendee? {
        guard let name = dict["name"] as? String else { return nil }
        let id = (dict["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        return NetworkEvent.Attendee(
            id: id,
            name: name,
            email: dict["email"] as? String,
            role: dict["role"] as? String,
            organization: dict["organization"] as? String,
            contactId: dict["contactId"] as? String
        )
    }
}
