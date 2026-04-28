import Foundation

@MainActor
final class CalendarEventStatusService: ObservableObject {
    static let shared = CalendarEventStatusService()

    @Published private(set) var statusByEventId: [String: CalendarEventStatus] = [:]

    private let store: JSONStore
    private static let storageKey = "equilibrium.calendar.eventStatuses"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        let array = store.load([CalendarEventStatus].self, key: Self.storageKey) ?? []
        var map: [String: CalendarEventStatus] = [:]
        for entry in array { map[entry.eventIdentifier] = entry }
        statusByEventId = map
    }

    func status(for eventIdentifier: String) -> CalendarEventStatus? {
        statusByEventId[eventIdentifier]
    }

    func set(eventIdentifier: String, status: CalendarEventStatus.Status, note: String? = nil) {
        let entry = CalendarEventStatus(
            eventIdentifier: eventIdentifier,
            status: status,
            statusSetAt: Date(),
            note: note
        )
        statusByEventId[eventIdentifier] = entry
        persist()
    }

    func clear(eventIdentifier: String) {
        statusByEventId.removeValue(forKey: eventIdentifier)
        persist()
    }

    private func persist() {
        store.save(Array(statusByEventId.values), key: Self.storageKey)
    }
}
