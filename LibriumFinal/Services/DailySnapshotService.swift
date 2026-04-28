import Foundation

@MainActor
final class DailySnapshotService: ObservableObject {
    static let shared = DailySnapshotService()

    @Published private(set) var snapshots: [DimensionSnapshot] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.life.snapshots"
    private static let cap = 730   // ~2 years of daily rows

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        let raw = store.load([DimensionSnapshot].self, key: Self.storageKey) ?? []
        snapshots = raw.sorted { $0.date < $1.date }
    }

    /// Compute today's live score on demand (not persisted until tomorrow's rollup).
    func currentLive(now: Date = Date()) async -> DimensionSnapshot {
        await snapshotInputs(for: now)
    }

    /// Run on app launch — fills in any missing daily snapshots from the last persisted date through yesterday.
    func rollupIfNeeded(now: Date = Date()) async {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now)) ?? now

        let lastDate: Date
        if let last = snapshots.last {
            lastDate = last.date
        } else {
            // First run — only roll up yesterday so we don't backfill empty history
            lastDate = yesterday
        }

        var cursor = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: lastDate)) ?? yesterday
        let yesterdayStart = cal.startOfDay(for: yesterday)

        var added = false
        while cursor <= yesterdayStart {
            let snap = await snapshotInputs(for: cursor)
            // Only persist if we don't already have it (defensive)
            if !snapshots.contains(where: { $0.id == snap.id }) {
                snapshots.append(snap)
                added = true
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        if added {
            snapshots.sort { $0.date < $1.date }
            if snapshots.count > Self.cap {
                snapshots = Array(snapshots.suffix(Self.cap))
            }
            persist()
        }
    }

    func snapshots(in window: Int, now: Date = Date()) -> [DimensionSnapshot] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -window, to: now) else { return [] }
        return snapshots.filter { $0.date >= start }
    }

    // MARK: - Compute

    private func snapshotInputs(for date: Date) async -> DimensionSnapshot {
        let events = LifeEventsService.shared.events
        let cal = Calendar.current
        let isToday = cal.isDate(date, inSameDayAs: Date())

        // Body data — pull from HealthKit + manual logs
        let healthSnapshot = await HealthKitService.shared.loadSnapshot(now: date)
        let manualLog = WellnessLogService.shared.today() // closest signal we have for non-today days
        let sleepHours = isToday
            ? max(healthSnapshot.sleepHours, manualLog.sleepHours)
            : (cal.isDateInToday(manualLog.date) ? healthSnapshot.sleepHours : healthSnapshot.sleepHours)
        let steps = healthSnapshot.stepCount
        let mindful = healthSnapshot.mindfulMinutes
        let waterGlasses = isToday ? manualLog.waterGlasses : Int(healthSnapshot.waterOunces / 16.0)

        // Mood — from journal entry of that day
        let journalMood: Int
        if isToday {
            journalMood = JournalService.shared.today().mood
        } else if let entry = JournalService.shared.entry(for: date) {
            journalMood = entry.mood
        } else {
            journalMood = 0
        }

        // Work composite — current accountability score (we don't snapshot historical accountability yet)
        let workComposite = GoalsService.shared.accountabilityScore(now: date).overall * 100.0

        return LifeScoreCalculator.compute(
            for: date,
            events: events,
            sleepHours: sleepHours,
            steps: steps,
            waterGlasses: waterGlasses,
            mindfulMinutes: mindful,
            journalMood: journalMood,
            workComposite: workComposite
        )
    }

    private func persist() {
        store.save(snapshots, key: Self.storageKey)
    }
}
