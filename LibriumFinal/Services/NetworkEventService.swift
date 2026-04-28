import Foundation

@MainActor
final class NetworkEventService: ObservableObject {
    static let shared = NetworkEventService()

    @Published private(set) var events: [NetworkEvent] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.network.events"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        events = store.load([NetworkEvent].self, key: Self.storageKey) ?? []
        events.sort { $0.startDate < $1.startDate }
    }

    func upsert(_ event: NetworkEvent, syncToFirestore: Bool = true) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        } else {
            events.append(event)
        }
        events.sort { $0.startDate < $1.startDate }
        persist()

        if syncToFirestore {
            Task.detached {
                _ = try? await FirestoreEventService.shared.upload(event)
            }
        }
    }

    func delete(id: UUID, syncToFirestore: Bool = true) {
        events.removeAll { $0.id == id }
        persist()

        if syncToFirestore {
            Task.detached {
                try? await FirestoreEventService.shared.delete(id: id)
            }
        }
    }

    @discardableResult
    func pull(id: UUID) async -> NetworkEvent? {
        do {
            guard let event = try await FirestoreEventService.shared.fetch(id: id) else {
                return nil
            }
            upsert(event, syncToFirestore: false)
            return event
        } catch {
            return nil
        }
    }

    func rsvp(eventId: UUID, attendee: NetworkEvent.Attendee) async -> Bool {
        do {
            try await FirestoreEventService.shared.rsvp(eventId: eventId, attendee: attendee)
            // Refresh local copy
            await pull(id: eventId)
            return true
        } catch {
            return false
        }
    }

    var liveEvent: NetworkEvent? {
        events.first { $0.isLive }
    }

    var upcomingEvents: [NetworkEvent] {
        events.filter { $0.isUpcoming || $0.isLive }
    }

    func event(named name: String) -> NetworkEvent? {
        let needle = name.lowercased()
        return events.first { $0.name.lowercased().contains(needle) }
    }

    private func persist() {
        store.save(events, key: Self.storageKey)
    }
}
