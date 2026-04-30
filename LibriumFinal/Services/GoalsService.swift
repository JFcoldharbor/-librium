import FirebaseFirestore
import Foundation

@MainActor
final class GoalsService: ObservableObject {
    static let shared = GoalsService()

    @Published private(set) var goals: [Goal] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.work.goals"
    private static let migrationFlagKey = "equilibrium.work.goals.firestoreMigrated"

    private var listener: ListenerRegistration?

    init(store: JSONStore = .shared) {
        self.store = store
        load()
        startSync()
    }

    deinit {
        listener?.remove()
    }

    func load() {
        goals = store.load([Goal].self, key: Self.storageKey) ?? []
    }

    func upsert(_ goal: Goal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[idx] = goal
        } else {
            goals.append(goal)
        }
        persist()
        Task { try? await GoalsFirestoreService.shared.upsert(goal) }
    }

    func delete(id: UUID) {
        goals.removeAll { $0.id == id }
        persist()
        Task { try? await GoalsFirestoreService.shared.delete(id: id) }
    }

    func markCompleted(id: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[idx].status = .completed
        goals[idx].completedAt = Date()
        let updated = goals[idx]
        persist()
        Task { try? await GoalsFirestoreService.shared.upsert(updated) }
    }

    func markActive(id: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[idx].status = .active
        goals[idx].completedAt = nil
        let updated = goals[idx]
        persist()
        Task { try? await GoalsFirestoreService.shared.upsert(updated) }
    }

    func markMissed(id: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[idx].status = .missed
        goals[idx].completedAt = Date()
        let updated = goals[idx]
        persist()
        Task { try? await GoalsFirestoreService.shared.upsert(updated) }
    }

    func active(in timeframe: Goal.Timeframe) -> [Goal] {
        goals
            .filter { $0.timeframe == timeframe && $0.status == .active }
            .sorted { goalSortKey($0) < goalSortKey($1) }
    }

    func all(in timeframe: Goal.Timeframe) -> [Goal] {
        goals
            .filter { $0.timeframe == timeframe }
            .sorted { goalSortKey($0) < goalSortKey($1) }
    }

    func todayGoals() -> [Goal] {
        let today = Calendar.current.startOfDay(for: Date())
        return goals.filter { goal in
            guard goal.timeframe == .daily, goal.status == .active else { return false }
            if let target = goal.targetDate {
                return Calendar.current.isDate(target, inSameDayAs: today)
            }
            return Calendar.current.isDate(goal.createdAt, inSameDayAs: today)
        }
    }

    func completionRate(timeframe: Goal.Timeframe) -> Double {
        let scoped = goals.filter { $0.timeframe == timeframe }
        guard !scoped.isEmpty else { return 0 }
        let done = scoped.filter { $0.status == .completed }.count
        return Double(done) / Double(scoped.count)
    }

    // MARK: - Accountability

    func stats(for timeframe: Goal.Timeframe, weight: Double) -> AccountabilityScore.TimeframeStats {
        let scoped = goals.filter { $0.timeframe == timeframe }
        let completed = scoped.filter { $0.status == .completed }.count
        let missed = scoped.filter { $0.status == .missed }.count
        let dropped = scoped.filter { $0.status == .dropped }.count
        let denominator = completed + missed
        let rate: Double? = denominator > 0 ? Double(completed) / Double(denominator) : nil
        return AccountabilityScore.TimeframeStats(
            completed: completed,
            missed: missed,
            dropped: dropped,
            weight: weight,
            rate: rate
        )
    }

    func accountabilityScore(now: Date = Date()) -> AccountabilityScore {
        let w = AccountabilityScore.weights
        let daily = stats(for: .daily, weight: w.daily)
        let weekly = stats(for: .weekly, weight: w.weekly)
        let quarter = stats(for: Goal.Timeframe.currentQuarter(now: now), weight: w.quarter)
        let yearly = stats(for: .yearly, weight: w.yearly)

        let blocks = [daily, weekly, quarter, yearly]
        let active = blocks.filter { $0.hasData }
        let totalWeight = active.reduce(0) { $0 + $1.weight }
        let overall: Double
        if totalWeight > 0 {
            overall = active.reduce(0) { acc, block in
                acc + (block.rate ?? 0) * (block.weight / totalWeight)
            }
        } else {
            overall = 0
        }

        let calendar = CalendarEventStatusService.shared.statusByEventId.values
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let completedCal = calendar.filter { $0.status == .completed && $0.statusSetAt >= cutoff }.count
        let missedCal = calendar.filter { $0.status == .missed && $0.statusSetAt >= cutoff }.count
        let reschedCal = calendar.filter { $0.status == .needsReschedule && $0.statusSetAt >= cutoff }.count

        return AccountabilityScore(
            daily: daily,
            weekly: weekly,
            quarter: quarter,
            yearly: yearly,
            calendarCompleted7d: completedCal,
            calendarMissed7d: missedCal,
            calendarRescheduled7d: reschedCal,
            overall: overall
        )
    }

    private func goalSortKey(_ goal: Goal) -> Date {
        goal.targetDate ?? goal.createdAt
    }

    private func persist() {
        store.save(goals, key: Self.storageKey)
    }

    private func startSync() {
        Task { [weak self] in
            await self?.migrateLocalIfNeeded()
            await MainActor.run { self?.attachListener() }
        }
    }

    private func attachListener() {
        listener?.remove()
        listener = GoalsFirestoreService.shared.listen { [weak self] remote in
            guard let self else { return }
            self.goals = remote.sorted { $0.createdAt > $1.createdAt }
            self.persist()
        }
    }

    private func migrateLocalIfNeeded() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.migrationFlagKey) { return }
        let local = await MainActor.run { self.goals }
        guard !local.isEmpty else {
            defaults.set(true, forKey: Self.migrationFlagKey)
            return
        }
        do {
            let remote = try await GoalsFirestoreService.shared.fetchAll()
            if remote.isEmpty {
                for g in local {
                    try? await GoalsFirestoreService.shared.upsert(g)
                }
            }
            defaults.set(true, forKey: Self.migrationFlagKey)
        } catch {}
    }
}
