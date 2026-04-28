import Foundation

@MainActor
final class LifeEventsService: ObservableObject {
    static let shared = LifeEventsService()

    @Published private(set) var events: [LifeEvent] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.life.events"
    private static let cap = 2000   // keep the data graph from blowing up

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        let raw = store.load([LifeEvent].self, key: Self.storageKey) ?? []
        events = raw.sorted { $0.occurredAt > $1.occurredAt }
    }

    func upsert(_ event: LifeEvent) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        } else {
            events.append(event)
        }
        events.sort { $0.occurredAt > $1.occurredAt }
        if events.count > Self.cap {
            events = Array(events.prefix(Self.cap))
        }
        persist()
    }

    func delete(id: UUID) {
        events.removeAll { $0.id == id }
        persist()
    }

    /// Events occurring within the given window [since, until].
    func events(since start: Date, until end: Date = Date()) -> [LifeEvent] {
        events.filter { $0.occurredAt >= start && $0.occurredAt <= end }
    }

    /// Events on a single day (local time).
    func events(on day: Date) -> [LifeEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events(since: start, until: end)
    }

    private func persist() {
        store.save(events, key: Self.storageKey)
    }
}
