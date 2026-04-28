import Foundation

@MainActor
final class EventPriorityService: ObservableObject {
    static let shared = EventPriorityService()

    @Published private(set) var priorityByEventId: [String: EventPriority] = [:]

    private let store: JSONStore
    private static let storageKey = "equilibrium.calendar.eventPriorities"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        let array = store.load([EventPriority].self, key: Self.storageKey) ?? []
        var map: [String: EventPriority] = [:]
        for entry in array { map[entry.eventIdentifier] = entry }
        priorityByEventId = map
    }

    func priority(for eventIdentifier: String) -> EventPriority.Level? {
        priorityByEventId[eventIdentifier]?.level
    }

    func set(eventIdentifier: String, level: EventPriority.Level) {
        let entry = EventPriority(eventIdentifier: eventIdentifier, level: level, setAt: Date())
        priorityByEventId[eventIdentifier] = entry
        persist()
    }

    func clear(eventIdentifier: String) {
        priorityByEventId.removeValue(forKey: eventIdentifier)
        persist()
    }

    private func persist() {
        store.save(Array(priorityByEventId.values), key: Self.storageKey)
    }
}
