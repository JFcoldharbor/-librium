import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Per-event suggestion data: attendees ranked by relevance to the user, with
/// one-sentence conversation openers per attendee. Driven by the server-side
/// `mariaEventSuggestion` Cloud Function which writes to:
///   users/{uid}/eventSuggestions/{eventId}
///
/// Pattern is intentionally similar to ScannerCoordinator — listen to the
/// Firestore doc, expose @Published outputs, drive the Event Mode remote view.
@MainActor
final class EventSuggestionService: ObservableObject {
    static let shared = EventSuggestionService()

    @Published private(set) var byEventId: [UUID: EventSuggestion] = [:]
    @Published private(set) var pendingFor: Set<UUID> = []

    private let db = Firestore.firestore()
    private var listeners: [UUID: ListenerRegistration] = [:]

    private static let endpoint = URL(string: "https://mariaeventsuggestion-wzmwocctla-uc.a.run.app")!

    private init() {}

    /// Subscribe to suggestions for the given event. Idempotent.
    func observe(eventId: UUID) {
        guard listeners[eventId] == nil else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let docRef = db.collection("users").document(uid)
            .collection("eventSuggestions").document(eventId.uuidString.uppercased())

        listeners[eventId] = docRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let data = snapshot?.data() else { return }
            let suggestion = Self.decode(eventId: eventId, data: data)
            Task { @MainActor in
                if let suggestion {
                    self?.byEventId[eventId] = suggestion
                }
            }
        }
    }

    func stopObserving(eventId: UUID) {
        listeners[eventId]?.remove()
        listeners[eventId] = nil
    }

    /// Trigger the Cloud Function to (re)generate suggestions for this event.
    /// Listener picks up the result automatically.
    func refresh(eventId: UUID) async {
        let id = eventId
        if pendingFor.contains(id) { return }
        guard let user = Auth.auth().currentUser else { return }

        pendingFor.insert(id)
        defer { pendingFor.remove(id) }

        do {
            let token = try await user.getIDToken()
            var request = URLRequest(url: Self.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let body: [String: Any] = ["eventId": eventId.uuidString.uppercased()]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("EventSuggestionService refresh non-2xx: \(http.statusCode)")
            }
        } catch {
            print("EventSuggestionService refresh failed: \(error.localizedDescription)")
        }
    }

    private static func decode(eventId: UUID, data: [String: Any]) -> EventSuggestion? {
        let userVibe = (data["userVibe"] as? String).flatMap { AttendeeIntent(rawValue: $0) } ?? .default
        let attendeeCount = data["attendeeCount"] as? Int ?? 0

        let rankedRaw = data["ranked"] as? [[String: Any]] ?? []
        let ranked = rankedRaw.compactMap { dict -> RankedAttendee? in
            guard let idStr = dict["attendeeId"] as? String,
                  let id = UUID(uuidString: idStr) else { return nil }
            let score = dict["score"] as? Int ?? 50
            let reason = dict["reason"] as? String ?? ""
            return RankedAttendee(attendeeId: id, score: score, reason: reason)
        }

        let openersRaw = data["openers"] as? [[String: Any]] ?? []
        var openers: [UUID: String] = [:]
        for dict in openersRaw {
            if let idStr = dict["attendeeId"] as? String,
               let id = UUID(uuidString: idStr),
               let text = dict["text"] as? String {
                openers[id] = text
            }
        }

        let generatedAt = (data["generatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return EventSuggestion(
            eventId: eventId,
            userVibe: userVibe,
            attendeeCount: attendeeCount,
            ranked: ranked,
            openers: openers,
            generatedAt: generatedAt
        )
    }
}

struct EventSuggestion: Equatable {
    let eventId: UUID
    let userVibe: AttendeeIntent
    let attendeeCount: Int
    let ranked: [RankedAttendee]
    let openers: [UUID: String]
    let generatedAt: Date

    /// Returns the attendees in the suggested order. Anyone in `attendees`
    /// not present in `ranked` falls to the end in their original order.
    func ordered(_ attendees: [NetworkEvent.Attendee]) -> [NetworkEvent.Attendee] {
        let rankedIds = ranked.map { $0.attendeeId }
        let byId = Dictionary(uniqueKeysWithValues: attendees.map { ($0.id, $0) })
        var result: [NetworkEvent.Attendee] = []
        var seen: Set<UUID> = []
        for id in rankedIds {
            if let a = byId[id] {
                result.append(a)
                seen.insert(id)
            }
        }
        for a in attendees where !seen.contains(a.id) {
            result.append(a)
        }
        return result
    }

    func opener(for attendeeId: UUID) -> String? {
        openers[attendeeId]
    }
}

struct RankedAttendee: Equatable {
    let attendeeId: UUID
    let score: Int
    let reason: String
}
