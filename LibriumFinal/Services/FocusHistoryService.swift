import Foundation

@MainActor
final class FocusHistoryService {
    static let shared = FocusHistoryService()

    private let store: JSONStore
    private static let storageKey = "equilibrium.work.focus.sessions"
    private static let cap = 200

    init(store: JSONStore = .shared) {
        self.store = store
    }

    func loadAll() -> [FocusSession] {
        store.load([FocusSession].self, key: Self.storageKey) ?? []
    }

    func record(_ session: FocusSession) {
        var sessions = loadAll()
        sessions.append(session)
        if sessions.count > Self.cap {
            sessions = Array(sessions.suffix(Self.cap))
        }
        store.save(sessions, key: Self.storageKey)
    }

    func sessionsToday() -> [FocusSession] {
        let cal = Calendar.current
        return loadAll().filter { cal.isDate($0.startedAt, inSameDayAs: Date()) }
    }

    func sessionsThisWeek() -> [FocusSession] {
        let cal = Calendar.current
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return loadAll().filter { $0.startedAt >= weekAgo }
    }

    func minutesToday() -> Int {
        sessionsToday().reduce(0) { $0 + $1.minutes }
    }

    func completedSessionsToday() -> Int {
        sessionsToday().filter { $0.completed }.count
    }
}
