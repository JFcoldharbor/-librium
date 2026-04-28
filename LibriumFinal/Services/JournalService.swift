import Foundation

@MainActor
final class JournalService {
    static let shared = JournalService()

    private let store: JSONStore
    private static let storageKey = "equilibrium.life.journal.entries"

    init(store: JSONStore = .shared) {
        self.store = store
    }

    func loadAll() -> [JournalEntry] {
        store.load([JournalEntry].self, key: Self.storageKey) ?? []
    }

    func entry(for date: Date) -> JournalEntry? {
        let day = Calendar.current.startOfDay(for: date)
        return loadAll().first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func today() -> JournalEntry {
        entry(for: Date()) ?? .makeForToday()
    }

    func yesterday() -> JournalEntry? {
        guard let date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return nil
        }
        return entry(for: date)
    }

    func upsert(_ entry: JournalEntry) {
        var entries = loadAll()
        let cal = Calendar.current
        if let idx = entries.firstIndex(where: { cal.isDate($0.date, inSameDayAs: entry.date) }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { $0.date > $1.date }
        store.save(entries, key: Self.storageKey)
    }

    func currentStreak() -> Int {
        let entries = loadAll()
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        let today = entries.first { cal.isDate($0.date, inSameDayAs: checkDate) }
        if today?.hasContent != true {
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = prev
        }

        while true {
            let entry = entries.first { cal.isDate($0.date, inSameDayAs: checkDate) }
            guard let entry, entry.hasContent else { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }
}
