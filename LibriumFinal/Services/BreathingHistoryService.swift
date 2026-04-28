import Foundation

@MainActor
final class BreathingHistoryService {
    static let shared = BreathingHistoryService()

    private let store: JSONStore
    private static let storageKey = "equilibrium.life.breathing.sessions"
    private static let cap = 200

    init(store: JSONStore = .shared) {
        self.store = store
    }

    func loadAll() -> [BreathingSession] {
        store.load([BreathingSession].self, key: Self.storageKey) ?? []
    }

    func record(_ session: BreathingSession) {
        var sessions = loadAll()
        sessions.append(session)
        if sessions.count > Self.cap {
            sessions = Array(sessions.suffix(Self.cap))
        }
        store.save(sessions, key: Self.storageKey)
    }

    func sessionsToday() -> [BreathingSession] {
        let cal = Calendar.current
        return loadAll().filter { cal.isDate($0.date, inSameDayAs: Date()) }
    }

    func cyclesToday() -> Int {
        sessionsToday().reduce(0) { $0 + $1.cyclesCompleted }
    }

    func minutesToday() -> Int {
        sessionsToday().reduce(0) { $0 + $1.totalSeconds } / 60
    }
}
